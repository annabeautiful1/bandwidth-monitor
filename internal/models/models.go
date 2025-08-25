package models

import (
	"encoding/json"
	"log"
	"os"
	"time"
)

// ServerConfig 服务端配置
type ServerConfig struct {
	Password   string    `json:"password"`
	Listen     string    `json:"listen"`
	Domain     string    `json:"domain"`
	Telegram   TGConfig  `json:"telegram"`
	Thresholds Threshold `json:"thresholds"`
}

// TGConfig Telegram配置
type TGConfig struct {
	BotToken string `json:"bot_token"`
	ChatID   int64  `json:"chat_id"`
}

// Threshold 监控阈值配置
type Threshold struct {
	BandwidthMbps    float64 `json:"bandwidth_mbps"`
	OfflineSeconds   int     `json:"offline_seconds"`
	CPUPercent       float64 `json:"cpu_percent"`        // CPU占用告警阈值
	MemoryPercent    float64 `json:"memory_percent"`     // 内存占用告警阈值
}

// TimeWindowThreshold 按时间窗口动态阈值
type TimeWindowThreshold struct {
	Start         string  `json:"start"` // HH:MM
	End           string  `json:"end"`   // HH:MM
	BandwidthMbps float64 `json:"bandwidth_mbps"`
}

// ClientThresholdConfig 客户端阈值（静态 + 动态表）
type ClientThresholdConfig struct {
	StaticBandwidthMbps float64               `json:"static_bandwidth_mbps"`
	Dynamic             []TimeWindowThreshold `json:"dynamic"`
}

// ClientConfig 客户端配置
type ClientConfig struct {
	Password              string                `json:"password"`
	ServerURL             string                `json:"server_url"`
	Hostname              string                `json:"hostname"`
	ReportIntervalSeconds int                   `json:"report_interval_seconds"`
	InterfaceName         string                `json:"interface_name"`
	Threshold             ClientThresholdConfig `json:"threshold"`
}

// SystemMetrics 系统指标数据
type SystemMetrics struct {
	CPUPercent    float64 `json:"cpu_percent"`
	MemoryUsed    uint64  `json:"memory_used"`
	MemoryTotal   uint64  `json:"memory_total"`
	NetworkInBps  uint64  `json:"network_in_bps"`
	NetworkOutBps uint64  `json:"network_out_bps"`
	UptimeSeconds uint64  `json:"uptime_seconds"`
}

// ReportRequest 上报请求
type ReportRequest struct {
	Password               string        `json:"password"`
	Hostname               string        `json:"hostname"`
	Timestamp              int64         `json:"timestamp"`
	Metrics                SystemMetrics `json:"metrics"`
	EffectiveThresholdMbps float64       `json:"effective_threshold_mbps"`
}

// NodeStatus 节点状态
type NodeStatus struct {
	Hostname          string        `json:"hostname"`
	LastSeen          time.Time     `json:"last_seen"`
	Metrics           SystemMetrics `json:"metrics"`
	IsOnline          bool          `json:"is_online"`
	BandwidthAlerted  bool          `json:"bandwidth_alerted"`
	CPUAlerted        bool          `json:"cpu_alerted"`        // CPU告警状态
	MemoryAlerted     bool          `json:"memory_alerted"`     // 内存告警状态
	ReportSamples     int           `json:"report_samples"`
	LastThresholdMbps float64       `json:"last_threshold_mbps"`
}

// APIResponse 通用API响应
type APIResponse struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// LoadServerConfig 加载服务端配置并应用默认值
func LoadServerConfig(path string) (*ServerConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config ServerConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	// 自动应用默认值并保存配置文件
	if applyServerDefaults(&config) {
		if err := SaveServerConfig(path, &config); err != nil {
			log.Printf("保存配置默认值失败: %v", err)
		} else {
			log.Printf("配置文件已更新默认值: %s", path)
		}
	}

	return &config, nil
}

// SaveServerConfig 保存服务端配置
func SaveServerConfig(path string, config *ServerConfig) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

// LoadClientConfig 加载客户端配置并应用默认值
func LoadClientConfig(path string) (*ClientConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config ClientConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	// 自动应用默认值并保存配置文件
	if applyClientDefaults(&config) {
		if err := SaveClientConfig(path, &config); err != nil {
			log.Printf("保存配置默认值失败: %v", err)
		} else {
			log.Printf("配置文件已更新默认值: %s", path)
		}
	}

	return &config, nil
}

// SaveClientConfig 保存客户端配置
func SaveClientConfig(path string, config *ClientConfig) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

// applyServerDefaults 为服务端配置应用默认值
func applyServerDefaults(config *ServerConfig) bool {
	applied := false
	
	// 应用CPU阈值默认值
	if config.Thresholds.CPUPercent <= 0 {
		config.Thresholds.CPUPercent = 95.0
		applied = true
	}
	
	// 应用内存阈值默认值
	if config.Thresholds.MemoryPercent <= 0 {
		config.Thresholds.MemoryPercent = 95.0
		applied = true
	}
	
	// 应用带宽阈值默认值
	if config.Thresholds.BandwidthMbps <= 0 {
		config.Thresholds.BandwidthMbps = 100.0
		applied = true
	}
	
	// 应用离线阈值默认值
	if config.Thresholds.OfflineSeconds <= 0 {
		config.Thresholds.OfflineSeconds = 300
		applied = true
	}
	
	// 应用监听地址默认值
	if config.Listen == "" {
		config.Listen = ":8080"
		applied = true
	}
	
	// 应用域名默认值
	if config.Domain == "" {
		config.Domain = "localhost"
		applied = true
	}
	
	return applied
}

// applyClientDefaults 为客户端配置应用默认值
func applyClientDefaults(config *ClientConfig) bool {
	applied := false
	
	// 应用上报间隔默认值
	if config.ReportIntervalSeconds <= 0 {
		config.ReportIntervalSeconds = 60
		applied = true
	}
	
	// 应用主机名默认值
	if config.Hostname == "" {
		if hostname, err := os.Hostname(); err == nil {
			config.Hostname = hostname
		} else {
			config.Hostname = "unknown"
		}
		applied = true
	}
	
	// 应用动态阈值默认配置
	if len(config.Threshold.Dynamic) == 0 {
		config.Threshold.Dynamic = []TimeWindowThreshold{
			{Start: "22:00", End: "02:00", BandwidthMbps: 200}, // 高峰期
			{Start: "02:00", End: "09:00", BandwidthMbps: 50},  // 低谷期
			{Start: "09:00", End: "22:00", BandwidthMbps: 100}, // 平峰期
		}
		applied = true
	} else if len(config.Threshold.Dynamic) == 2 {
		// 从旧的2时段升级到3时段
		oldDynamic := config.Threshold.Dynamic
		config.Threshold.Dynamic = []TimeWindowThreshold{
			{Start: "22:00", End: "02:00", BandwidthMbps: oldDynamic[0].BandwidthMbps}, // 高峰期
			{Start: "02:00", End: "09:00", BandwidthMbps: oldDynamic[1].BandwidthMbps}, // 低谷期
			{Start: "09:00", End: "22:00", BandwidthMbps: 100},                        // 新增平峰期
		}
		applied = true
	}
	
	// 确保静态阈值有默认值（0表示禁用）
	if config.Threshold.StaticBandwidthMbps < 0 {
		config.Threshold.StaticBandwidthMbps = 0
		applied = true
	}
	
	return applied
}
