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
	BandwidthMbps  float64 `json:"bandwidth_mbps"`
	OfflineSeconds int     `json:"offline_seconds"`
}

// ClientConfig 客户端配置
type ClientConfig struct {
	Password              string `json:"password"`
	ServerURL             string `json:"server_url"`
	Hostname              string `json:"hostname"`
	ReportIntervalSeconds int    `json:"report_interval_seconds"`
	InterfaceName         string `json:"interface_name"`
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
	Password  string        `json:"password"`
	Hostname  string        `json:"hostname"`
	Timestamp int64         `json:"timestamp"`
	Metrics   SystemMetrics `json:"metrics"`
}

// NodeStatus 节点状态
type NodeStatus struct {
	Hostname         string        `json:"hostname"`
	LastSeen         time.Time     `json:"last_seen"`
	Metrics          SystemMetrics `json:"metrics"`
	IsOnline         bool          `json:"is_online"`
	BandwidthAlerted bool          `json:"bandwidth_alerted"`
	ReportSamples    int           `json:"report_samples"`
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
