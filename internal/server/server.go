package server

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"bandwidth-monitor/internal/models"
	"bandwidth-monitor/internal/telegram"
)

type Server struct {
	config *models.ServerConfig
	tgBot  *telegram.Bot
	nodes  map[string]*models.NodeStatus
	mutex  sync.RWMutex
	server *http.Server
}

func NewServer(config *models.ServerConfig, tgBot *telegram.Bot) *Server {
	return &Server{
		config: config,
		tgBot:  tgBot,
		nodes:  make(map[string]*models.NodeStatus),
	}
}

func (s *Server) Start() error {
	mux := http.NewServeMux()

	// API路由
	mux.HandleFunc("/api/report", s.handleReport)
	mux.HandleFunc("/api/status", s.handleStatus)
	mux.HandleFunc("/api/test-telegram", s.handleTestTelegram)

	// 启动监控goroutine
	go s.monitorNodes()

	s.server = &http.Server{
		Addr:    s.config.Listen,
		Handler: mux,
	}

	return s.server.ListenAndServe()
}

func (s *Server) Stop() {
	if s.server != nil {
		s.server.Close()
	}
}

func (s *Server) handleReport(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.sendResponse(w, false, "仅支持POST方法", nil)
		return
	}

	var req models.ReportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		s.sendResponse(w, false, "JSON解析失败", nil)
		return
	}

	// 验证密码
	if req.Password != s.config.Password {
		s.sendResponse(w, false, "密码错误", nil)
		return
	}

	// 更新节点状态（包含客户端上报的阈值）
	s.updateNodeStatus(req.Hostname, req.Metrics, req.EffectiveThresholdMbps)

	s.sendResponse(w, true, "上报成功", nil)
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	s.mutex.RLock()
	defer s.mutex.RUnlock()

	s.sendResponse(w, true, "获取状态成功", s.nodes)
}

func (s *Server) handleTestTelegram(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.sendResponse(w, false, "仅支持POST方法", nil)
		return
	}

	if s.tgBot == nil {
		s.sendResponse(w, false, "Telegram机器人未配置", nil)
		return
	}

	if err := s.tgBot.SendTestMessage(); err != nil {
		s.sendResponse(w, false, "发送测试消息失败: "+err.Error(), nil)
		return
	}

	s.sendResponse(w, true, "测试消息发送成功", nil)
}

func (s *Server) updateNodeStatus(hostname string, metrics models.SystemMetrics, thresholdMbps float64) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	now := time.Now()
	wasOffline := false
	isNew := false

	// 检查节点是否存在
	node, exists := s.nodes[hostname]
	if !exists {
		isNew = true
		node = &models.NodeStatus{
			Hostname:          hostname,
			IsOnline:          true,
			BandwidthAlerted:  false,
			CPUAlerted:        false,
			MemoryAlerted:     false,
			ReportSamples:     0,
			LastThresholdMbps: thresholdMbps,
		}
		s.nodes[hostname] = node
		log.Printf("新节点上线: %s", hostname)
	} else {
		wasOffline = !node.IsOnline
	}

	// 更新节点信息
	node.LastSeen = now
	node.Metrics = metrics
	node.IsOnline = true
	node.ReportSamples++
	if thresholdMbps > 0 {
		node.LastThresholdMbps = thresholdMbps
	}

	// 如果节点首次出现或重新上线，发送通知
	if s.tgBot != nil {
		if isNew || wasOffline {
			if err := s.tgBot.SendOnlineAlert(hostname); err != nil {
				log.Printf("发送上线告警失败: %v", err)
			}
		}
	}

	// 检查带宽告警（跳过首个样本防止冷启动误报）
	if node.ReportSamples >= 2 {
		s.checkBandwidthAlert(node)
		s.checkCPUAlert(node)
		s.checkMemoryAlert(node)
	}
}

func (s *Server) checkBandwidthAlert(node *models.NodeStatus) {
	// 计算当前带宽 (Mbps)
	inMbps := float64(node.Metrics.NetworkInBps) / 125000.0 // 1 Mbps = 125000 bytes/s
	outMbps := float64(node.Metrics.NetworkOutBps) / 125000.0
	currentMbps := inMbps
	if outMbps > inMbps {
		currentMbps = outMbps
	}

	// 取客户端上报阈值，若无则回退到服务端全局阈值
	threshold := node.LastThresholdMbps
	if threshold <= 0 {
		threshold = s.config.Thresholds.BandwidthMbps
	}

	// 检查是否需要告警
	if currentMbps < threshold {
		if !node.BandwidthAlerted {
			// 第一次触发告警
			node.BandwidthAlerted = true
			if s.tgBot != nil {
				if err := s.tgBot.SendBandwidthAlert(
					node.Hostname,
					currentMbps,
					threshold,
				); err != nil {
					log.Printf("发送带宽告警失败: %v", err)
				}
			}
			log.Printf("节点 %s 带宽告警: %.2f Mbps < %.2f Mbps",
				node.Hostname, currentMbps, threshold)
		}
	} else {
		// 带宽恢复正常
		if node.BandwidthAlerted {
			node.BandwidthAlerted = false
			if s.tgBot != nil {
				if err := s.tgBot.SendBandwidthRecover(node.Hostname, currentMbps, threshold); err != nil {
					log.Printf("发送恢复通知失败: %v", err)
				}
			}
			log.Printf("节点 %s 带宽恢复正常: %.2f Mbps", node.Hostname, currentMbps)
		}
	}
}

func (s *Server) monitorNodes() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		s.checkOfflineNodes()
	}
}

func (s *Server) checkOfflineNodes() {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	now := time.Now()
	offlineThreshold := time.Duration(s.config.Thresholds.OfflineSeconds) * time.Second

	for hostname, node := range s.nodes {
		if node.IsOnline && now.Sub(node.LastSeen) > offlineThreshold {
			// 节点离线
			node.IsOnline = false
			node.BandwidthAlerted = false // 重置带宽告警状态
			node.CPUAlerted = false       // 重置CPU告警状态
			node.MemoryAlerted = false    // 重置内存告警状态

			if s.tgBot != nil {
				if err := s.tgBot.SendOfflineAlert(hostname, now.Sub(node.LastSeen)); err != nil {
					log.Printf("发送离线告警失败: %v", err)
				}
			}

			log.Printf("节点 %s 离线，最后上报时间: %s", hostname, node.LastSeen.Format("2006-01-02 15:04:05"))
		}
	}
}

// checkCPUAlert 检查CPU告警
func (s *Server) checkCPUAlert(node *models.NodeStatus) {
	cpuThreshold := s.config.Thresholds.CPUPercent
	if cpuThreshold <= 0 {
		return // 未配置CPU阈值
	}

	currentCPU := node.Metrics.CPUPercent

	if currentCPU > cpuThreshold {
		if !node.CPUAlerted {
			// 第一次触发CPU告警
			node.CPUAlerted = true
			if s.tgBot != nil {
				if err := s.tgBot.SendCPUAlert(
					node.Hostname,
					currentCPU,
					cpuThreshold,
				); err != nil {
					log.Printf("发送CPU告警失败: %v", err)
				}
			}
			log.Printf("节点 %s CPU告警: %.2f%% > %.2f%%",
				node.Hostname, currentCPU, cpuThreshold)
		}
	} else {
		if node.CPUAlerted {
			// CPU使用率恢复正常
			node.CPUAlerted = false
			if s.tgBot != nil {
				if err := s.tgBot.SendCPURecover(
					node.Hostname,
					currentCPU,
					cpuThreshold,
				); err != nil {
					log.Printf("发送CPU恢复通知失败: %v", err)
				}
			}
			log.Printf("节点 %s CPU已恢复: %.2f%% <= %.2f%%",
				node.Hostname, currentCPU, cpuThreshold)
		}
	}
}

// checkMemoryAlert 检查内存告警
func (s *Server) checkMemoryAlert(node *models.NodeStatus) {
	memoryThreshold := s.config.Thresholds.MemoryPercent
	if memoryThreshold <= 0 {
		return // 未配置内存阈值
	}

	// 计算内存使用百分比
	currentMemory := float64(node.Metrics.MemoryUsed) / float64(node.Metrics.MemoryTotal) * 100

	if currentMemory > memoryThreshold {
		if !node.MemoryAlerted {
			// 第一次触发内存告警
			node.MemoryAlerted = true
			if s.tgBot != nil {
				if err := s.tgBot.SendMemoryAlert(
					node.Hostname,
					currentMemory,
					memoryThreshold,
				); err != nil {
					log.Printf("发送内存告警失败: %v", err)
				}
			}
			log.Printf("节点 %s 内存告警: %.2f%% > %.2f%%",
				node.Hostname, currentMemory, memoryThreshold)
		}
	} else {
		if node.MemoryAlerted {
			// 内存使用率恢复正常
			node.MemoryAlerted = false
			if s.tgBot != nil {
				if err := s.tgBot.SendMemoryRecover(
					node.Hostname,
					currentMemory,
					memoryThreshold,
				); err != nil {
					log.Printf("发送内存恢复通知失败: %v", err)
				}
			}
			log.Printf("节点 %s 内存已恢复: %.2f%% <= %.2f%%",
				node.Hostname, currentMemory, memoryThreshold)
		}
	}
}

func (s *Server) sendResponse(w http.ResponseWriter, success bool, message string, data interface{}) {
	w.Header().Set("Content-Type", "application/json")

	response := models.APIResponse{
		Success: success,
		Message: message,
		Data:    data,
	}

	if !success {
		w.WriteHeader(http.StatusBadRequest)
	}

	json.NewEncoder(w).Encode(response)
}
