package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"bandwidth-monitor/internal/models"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

type Client struct {
	config       *models.ClientConfig
	httpClient   *http.Client
	stopChan     chan struct{}
	wg           sync.WaitGroup
	lastNetStats map[string]net.IOCountersStat
}

func NewClient(config *models.ClientConfig) *Client {
	return &Client{
		config: config,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		stopChan:     make(chan struct{}),
		lastNetStats: make(map[string]net.IOCountersStat),
	}
}

func (c *Client) Start() error {
	ticker := time.NewTicker(time.Duration(c.config.ReportIntervalSeconds) * time.Second)
	defer ticker.Stop()

	// 立即发送一次报告
	if err := c.reportMetrics(); err != nil {
		log.Printf("首次上报失败: %v", err)
	}

	for {
		select {
		case <-ticker.C:
			if err := c.reportMetrics(); err != nil {
				log.Printf("上报失败: %v", err)
			}
		case <-c.stopChan:
			return nil
		}
	}
}

func (c *Client) Stop() {
	close(c.stopChan)
	c.wg.Wait()
}

func (c *Client) reportMetrics() error {
	metrics, err := c.collectMetrics()
	if err != nil {
		return fmt.Errorf("收集指标失败: %v", err)
	}

	request := models.ReportRequest{
		Password:  c.config.Password,
		Hostname:  c.config.Hostname,
		Timestamp: time.Now().Unix(),
		Metrics:   *metrics,
	}

	return c.sendReport(request)
}

func (c *Client) collectMetrics() (*models.SystemMetrics, error) {
	// CPU使用率
	cpuPercent, err := cpu.Percent(time.Second, false)
	if err != nil || len(cpuPercent) == 0 {
		cpuPercent = []float64{0}
	}

	// 内存信息
	memInfo, err := mem.VirtualMemory()
	if err != nil {
		return nil, fmt.Errorf("获取内存信息失败: %v", err)
	}

	// 系统运行时间
	uptime, err := host.Uptime()
	if err != nil {
		uptime = 0
	}

	// 网络速率
	netInBps, netOutBps, err := c.getNetworkSpeed()
	if err != nil {
		log.Printf("获取网络速率失败: %v", err)
		netInBps, netOutBps = 0, 0
	}

	metrics := &models.SystemMetrics{
		CPUPercent:    cpuPercent[0],
		MemoryUsed:    memInfo.Used,
		MemoryTotal:   memInfo.Total,
		NetworkInBps:  netInBps,
		NetworkOutBps: netOutBps,
		UptimeSeconds: uptime,
	}

	return metrics, nil
}

func (c *Client) getNetworkSpeed() (uint64, uint64, error) {
	stats, err := net.IOCounters(false)
	if err != nil || len(stats) == 0 {
		return 0, 0, err
	}

	currentStats := stats[0]
	
	// 如果是第一次采集，记录当前值并返回0
	lastStats, exists := c.lastNetStats["total"]
	if !exists {
		c.lastNetStats["total"] = currentStats
		return 0, 0, nil
	}

	// 计算时间间隔
	interval := time.Duration(c.config.ReportIntervalSeconds) * time.Second
	
	// 计算速率 (bytes/s)
	bytesInDiff := currentStats.BytesRecv - lastStats.BytesRecv
	bytesOutDiff := currentStats.BytesSent - lastStats.BytesSent
	
	inBps := uint64(float64(bytesInDiff) / interval.Seconds())
	outBps := uint64(float64(bytesOutDiff) / interval.Seconds())

	// 更新上次的统计
	c.lastNetStats["total"] = currentStats

	return inBps, outBps, nil
}

func (c *Client) sendReport(request models.ReportRequest) error {
	jsonData, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("JSON编码失败: %v", err)
	}

	url := fmt.Sprintf("%s/api/report", c.config.ServerURL)
	resp, err := c.httpClient.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("HTTP请求失败: %v", err)
	}
	defer resp.Body.Close()

	var response models.APIResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return fmt.Errorf("响应解析失败: %v", err)
	}

	if !response.Success {
		return fmt.Errorf("服务器返回错误: %s", response.Message)
	}

	log.Printf("上报成功 - CPU: %.1f%%, 内存: %s/%s, 网络: ↓%.2fMbps ↑%.2fMbps",
		request.Metrics.CPUPercent,
		formatBytes(request.Metrics.MemoryUsed),
		formatBytes(request.Metrics.MemoryTotal),
		float64(request.Metrics.NetworkInBps)/125000.0,
		float64(request.Metrics.NetworkOutBps)/125000.0,
	)

	return nil
}

func formatBytes(bytes uint64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}