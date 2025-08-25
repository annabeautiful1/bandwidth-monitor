package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"bandwidth-monitor/internal/models"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

type Client struct {
	config        *models.ClientConfig
	configPath    string
	configMutex   sync.RWMutex
	httpClient    *http.Client
	stopChan      chan struct{}
	wg            sync.WaitGroup
	lastNetStats  map[string]net.IOCountersStat
	lastSampleAt  time.Time
	configModTime time.Time
}

func NewClient(config *models.ClientConfig, configPath string) *Client {
	return &Client{
		config:     config,
		configPath: configPath,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		stopChan:     make(chan struct{}),
		lastNetStats: make(map[string]net.IOCountersStat),
	}
}

func (c *Client) Start() error {
	// 初始化配置文件修改时间
	c.updateConfigModTime()

	// 启动配置监控 goroutine
	c.wg.Add(1)
	go c.configWatcher()

	// 选择监控网卡
	interfaceInfo := c.getInterfaceInfo()
	log.Printf("网卡配置: %s", interfaceInfo)

	currentInterval := c.getReportInterval()
	ticker := time.NewTicker(time.Duration(currentInterval) * time.Second)
	defer ticker.Stop()

	// 立即发送一次报告
	if err := c.reportMetrics(); err != nil {
		log.Printf("首次上报失败: %v", err)
	}

	for {
		select {
		case <-ticker.C:
			// 检查配置是否更新了上报间隔
			newInterval := c.getReportInterval()
			if newInterval != currentInterval {
				log.Printf("上报间隔已更新: %d秒 -> %d秒", currentInterval, newInterval)
				currentInterval = newInterval
				ticker.Stop()
				ticker = time.NewTicker(time.Duration(newInterval) * time.Second)
			}

			if err := c.reportMetrics(); err != nil {
				log.Printf("上报失败: %v", err)
			}
		case <-c.stopChan:
			return nil
		}
	}
}

// configWatcher 配置文件监控器
func (c *Client) configWatcher() {
	defer c.wg.Done()

	ticker := time.NewTicker(5 * time.Second) // 每5秒检查一次配置文件
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			if c.checkConfigUpdate() {
				if err := c.reloadConfig(); err != nil {
					log.Printf("重载配置失败: %v", err)
				} else {
					log.Printf("配置文件已重载")
				}
			}
		case <-c.stopChan:
			return
		}
	}
}

// checkConfigUpdate 检查配置文件是否有更新
func (c *Client) checkConfigUpdate() bool {
	info, err := os.Stat(c.configPath)
	if err != nil {
		return false
	}

	return info.ModTime().After(c.configModTime)
}

// updateConfigModTime 更新配置文件修改时间
func (c *Client) updateConfigModTime() {
	info, err := os.Stat(c.configPath)
	if err != nil {
		return
	}
	c.configModTime = info.ModTime()
}

// reloadConfig 重载配置文件
func (c *Client) reloadConfig() error {
	newConfig, err := models.LoadClientConfig(c.configPath)
	if err != nil {
		return fmt.Errorf("加载配置文件失败: %v", err)
	}

	c.configMutex.Lock()
	oldHostname := c.config.Hostname
	oldServerURL := c.config.ServerURL
	oldInterfaceName := c.config.InterfaceName

	c.config = newConfig
	c.configMutex.Unlock()

	c.updateConfigModTime()

	// 记录重要配置变化
	if newConfig.Hostname != oldHostname {
		log.Printf("主机名已更新: %s -> %s", oldHostname, newConfig.Hostname)
	}
	if newConfig.ServerURL != oldServerURL {
		log.Printf("服务器地址已更新: %s -> %s", oldServerURL, newConfig.ServerURL)
	}
	if newConfig.InterfaceName != oldInterfaceName {
		log.Printf("网卡设置已更新: %s -> %s", oldInterfaceName, newConfig.InterfaceName)
		// 网卡变更时重置统计缓存
		c.lastNetStats = make(map[string]net.IOCountersStat)
		// 更新网卡信息显示
		interfaceInfo := c.getInterfaceInfo()
		log.Printf("网卡配置: %s", interfaceInfo)
	}

	return nil
}

// 安全的配置访问方法
func (c *Client) getReportInterval() int {
	c.configMutex.RLock()
	defer c.configMutex.RUnlock()
	return c.config.ReportIntervalSeconds
}

func (c *Client) getInterfaceName() string {
	c.configMutex.RLock()
	defer c.configMutex.RUnlock()
	return c.config.InterfaceName
}

func (c *Client) getThresholdConfig() models.ClientThresholdConfig {
	c.configMutex.RLock()
	defer c.configMutex.RUnlock()
	return c.config.Threshold
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

	effectiveThreshold := c.getEffectiveThresholdMbps(time.Now())

	c.configMutex.RLock()
	password := c.config.Password
	hostname := c.config.Hostname
	serverURL := c.config.ServerURL
	c.configMutex.RUnlock()

	request := models.ReportRequest{
		Password:               password,
		Hostname:               hostname,
		Timestamp:              time.Now().Unix(),
		Metrics:                *metrics,
		EffectiveThresholdMbps: effectiveThreshold,
	}

	return c.sendReport(request, serverURL)
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
	// 获取每个网卡的统计
	stats, err := net.IOCounters(true)
	if err != nil || len(stats) == 0 {
		return 0, 0, err
	}

	var currentStats net.IOCountersStat
	var currentInBytes, currentOutBytes uint64
	var interfacesUsed []string

	interfaceName := c.getInterfaceName()

	// 如果指定了网卡名称，使用指定网卡
	if interfaceName != "" {
		found := false
		for _, s := range stats {
			if s.Name == interfaceName {
				currentStats = s
				currentInBytes = s.BytesRecv
				currentOutBytes = s.BytesSent
				interfacesUsed = []string{s.Name}
				found = true
				break
			}
		}
		if !found {
			return 0, 0, fmt.Errorf("指定的网卡 %s 未找到", interfaceName)
		}
	} else {
		// 默认情况：统计所有非回环和非虚拟网卡的总和
		for _, s := range stats {
			if s.Name != "lo" && !isVirtualName(s.Name) {
				currentInBytes += s.BytesRecv
				currentOutBytes += s.BytesSent
				interfacesUsed = append(interfacesUsed, s.Name)
			}
		}

		if len(interfacesUsed) == 0 {
			return 0, 0, fmt.Errorf("未找到可用的物理网卡")
		}

		// 为总和创建虚拟统计结构
		currentStats = net.IOCountersStat{
			Name:      "total", // 使用特殊标识符
			BytesRecv: currentInBytes,
			BytesSent: currentOutBytes,
		}
	}

	// 生成统计键名
	statsKey := c.getStatsKey(interfacesUsed, interfaceName)

	// 如果是第一次采集，记录并返回0（避免冷启动高估）
	lastStats, exists := c.lastNetStats[statsKey]
	now := time.Now()
	if !exists {
		c.lastNetStats[statsKey] = currentStats
		c.lastSampleAt = now
		return 0, 0, nil
	}

	// 用真实间隔计算速度
	elapsed := now.Sub(c.lastSampleAt).Seconds()
	if elapsed <= 0 {
		elapsed = float64(c.getReportInterval())
	}

	bytesInDiff := currentStats.BytesRecv - lastStats.BytesRecv
	bytesOutDiff := currentStats.BytesSent - lastStats.BytesSent

	inBps := uint64(float64(bytesInDiff) / elapsed)
	outBps := uint64(float64(bytesOutDiff) / elapsed)

	c.lastNetStats[statsKey] = currentStats
	c.lastSampleAt = now

	return inBps, outBps, nil
}

// getStatsKey 生成统计键名
func (c *Client) getStatsKey(interfaces []string, interfaceName string) string {
	if interfaceName != "" {
		return interfaceName
	}
	// 对于总和统计，使用所有网卡名称组合
	if len(interfaces) == 0 {
		return "total"
	}
	return fmt.Sprintf("total_%s", strings.Join(interfaces, "_"))
}

func (c *Client) sendReport(request models.ReportRequest, serverURL string) error {
	jsonData, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("JSON编码失败: %v", err)
	}

	url := fmt.Sprintf("%s/api/report", serverURL)
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

	log.Printf("上报成功 - CPU: %.1f%%, 内存: %s/%s, 网络: ↓%.2fMbps ↑%.2fMbps (阈值: %.2fMbps)",
		request.Metrics.CPUPercent,
		formatBytes(request.Metrics.MemoryUsed),
		formatBytes(request.Metrics.MemoryTotal),
		float64(request.Metrics.NetworkInBps)/125000.0,
		float64(request.Metrics.NetworkOutBps)/125000.0,
		request.EffectiveThresholdMbps,
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

// getInterfaceInfo 获取网卡配置信息用于日志显示
func (c *Client) getInterfaceInfo() string {
	interfaceName := c.getInterfaceName()
	if interfaceName != "" {
		return fmt.Sprintf("指定网卡 %s", interfaceName)
	}

	// 获取所有可用的物理网卡
	stats, err := net.IOCounters(true)
	if err != nil {
		return "网卡信息获取失败"
	}

	var physicalIfaces []string
	for _, s := range stats {
		if s.Name != "lo" && !isVirtualName(s.Name) {
			physicalIfaces = append(physicalIfaces, s.Name)
		}
	}

	if len(physicalIfaces) == 0 {
		return "未找到可用的物理网卡"
	}

	return fmt.Sprintf("自动统计所有物理网卡总和: %s", strings.Join(physicalIfaces, ", "))
}

func isVirtualName(name string) bool {
	lower := strings.ToLower(name)
	prefixes := []string{"veth", "docker", "br-", "virbr", "vmnet", "zt", "tailscale", "wg"}
	for _, p := range prefixes {
		if strings.HasPrefix(lower, p) {
			return true
		}
	}
	return false
}

// getEffectiveThresholdMbps 计算当前时间的有效阈值（动态优先，fallback到静态）
func (c *Client) getEffectiveThresholdMbps(now time.Time) float64 {
	thresholdConfig := c.getThresholdConfig()

	// 动态阈值
	for _, w := range thresholdConfig.Dynamic {
		if inWindow(now, w.Start, w.End) {
			if w.BandwidthMbps > 0 {
				return w.BandwidthMbps
			}
		}
	}
	// 静态阈值
	if thresholdConfig.StaticBandwidthMbps > 0 {
		return thresholdConfig.StaticBandwidthMbps
	}
	return 0
}

func inWindow(now time.Time, startHHMM, endHHMM string) bool {
	start, ok1 := parseHHMM(startHHMM)
	end, ok2 := parseHHMM(endHHMM)
	if !ok1 || !ok2 {
		return false
	}
	mins := now.Hour()*60 + now.Minute()
	if start <= end {
		return mins >= start && mins < end
	}
	// 跨午夜窗口，例如 22:00-02:00
	return mins >= start || mins < end
}

func parseHHMM(s string) (int, bool) {
	if len(s) != 5 || s[2] != ':' {
		return 0, false
	}
	h := int(s[0]-'0')*10 + int(s[1]-'0')
	m := int(s[3]-'0')*10 + int(s[4]-'0')
	if h < 0 || h > 23 || m < 0 || m > 59 {
		return 0, false
	}
	return h*60 + m, true
}
