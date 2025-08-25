package models

import (
	"encoding/json"
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

// LoadServerConfig 加载服务端配置
func LoadServerConfig(path string) (*ServerConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config ServerConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
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

// LoadClientConfig 加载客户端配置
func LoadClientConfig(path string) (*ClientConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config ClientConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
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

// UpgradeServerConfig 升级服务端配置，添加缺失的默认值
func UpgradeServerConfig(config *ServerConfig) bool {
	upgraded := false
	
	// 添加CPU阈值默认值
	if config.Thresholds.CPUPercent <= 0 {
		config.Thresholds.CPUPercent = 95.0
		upgraded = true
	}
	
	// 添加内存阈值默认值
	if config.Thresholds.MemoryPercent <= 0 {
		config.Thresholds.MemoryPercent = 95.0
		upgraded = true
	}
	
	return upgraded
}

// UpgradeClientConfig 升级客户端配置，添加缺失的默认值
func UpgradeClientConfig(config *ClientConfig) bool {
	upgraded := false
	
	// 检查动态阈值配置是否为空或不完整
	if len(config.Threshold.Dynamic) == 0 {
		// 设置默认的3时段配置
		config.Threshold.Dynamic = []TimeWindowThreshold{
			{Start: "22:00", End: "02:00", BandwidthMbps: 200}, // 高峰期
			{Start: "02:00", End: "09:00", BandwidthMbps: 50},  // 低谷期
			{Start: "09:00", End: "22:00", BandwidthMbps: 100}, // 平峰期
		}
		upgraded = true
	} else if len(config.Threshold.Dynamic) == 2 {
		// 从旧的2时段升级到3时段
		oldDynamic := config.Threshold.Dynamic
		config.Threshold.Dynamic = []TimeWindowThreshold{
			{Start: "22:00", End: "02:00", BandwidthMbps: 200}, // 高峰期
			{Start: "02:00", End: "09:00", BandwidthMbps: 50},  // 低谷期  
			{Start: "09:00", End: "22:00", BandwidthMbps: 100}, // 平峰期
		}
		// 尝试保留用户原有配置的阈值
		if len(oldDynamic) >= 1 {
			config.Threshold.Dynamic[0].BandwidthMbps = oldDynamic[0].BandwidthMbps
		}
		if len(oldDynamic) >= 2 {
			config.Threshold.Dynamic[1].BandwidthMbps = oldDynamic[1].BandwidthMbps
		}
		upgraded = true
	}
	
	return upgraded
}
