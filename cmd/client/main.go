package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"bandwidth-monitor/internal/client"
	"bandwidth-monitor/internal/models"
)

func main() {
	configPath := flag.String("config", "client.json", "配置文件路径")
	flag.Parse()

	// 加载配置
	config, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	// 创建客户端
	c := client.NewClient(config, *configPath)

	// 启动客户端
	go func() {
		log.Printf("客户端启动，连接到服务器: %s", config.ServerURL)
		log.Printf("上报间隔: %d秒", config.ReportIntervalSeconds)
		if config.InterfaceName != "" {
			log.Printf("指定网卡: %s", config.InterfaceName)
		}

		if err := c.Start(); err != nil {
			log.Fatalf("客户端运行失败: %v", err)
		}
	}()

	// 优雅关闭
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	log.Println("正在关闭客户端...")
	c.Stop()
	log.Println("客户端已关闭")
}

func loadConfig(path string) (*models.ClientConfig, error) {
	// 检查配置文件是否存在
	if _, err := os.Stat(path); os.IsNotExist(err) {
		// 创建默认配置文件
		hostname, _ := os.Hostname()
		if hostname == "" {
			hostname = "unknown-host"
		}

		defaultConfig := &models.ClientConfig{
			Password:              "your-password-here",
			ServerURL:             "http://your-server.com:8080",
			Hostname:              hostname,
			ReportIntervalSeconds: 60,
			InterfaceName:         "", // 留空将自动选择非回环网卡
			Threshold: models.ClientThresholdConfig{
				StaticBandwidthMbps: 0,
				Dynamic: []models.TimeWindowThreshold{
					{Start: "22:00", End: "02:00", BandwidthMbps: 200}, // 高峰期
					{Start: "02:00", End: "09:00", BandwidthMbps: 50},  // 低谷期
					{Start: "09:00", End: "22:00", BandwidthMbps: 100}, // 平峰期
				},
			},
		}

		if err := saveConfig(path, defaultConfig); err != nil {
			return nil, fmt.Errorf("创建默认配置文件失败: %v", err)
		}

		fmt.Printf("已创建默认配置文件: %s\n", path)
		fmt.Println("请编辑配置文件后重新启动客户端")
		os.Exit(0)
	}

	// 加载现有配置
	config, err := models.LoadClientConfig(path)
	if err != nil {
		return nil, err
	}
	
	// 检查并升级配置
	if models.UpgradeClientConfig(config) {
		log.Printf("检测到配置文件需要升级，正在自动升级...")
		if err := saveConfig(path, config); err != nil {
			log.Printf("保存升级后的配置失败: %v", err)
		} else {
			log.Printf("配置文件已升级，确保3时段动态阈值配置完整")
		}
	}
	
	return config, nil
}

func saveConfig(path string, config *models.ClientConfig) error {
	return models.SaveClientConfig(path, config)
}
