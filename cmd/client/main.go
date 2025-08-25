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
	c := client.NewClient(config)

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
		}

		if err := saveConfig(path, defaultConfig); err != nil {
			return nil, fmt.Errorf("创建默认配置文件失败: %v", err)
		}

		fmt.Printf("已创建默认配置文件: %s\n", path)
		fmt.Println("请编辑配置文件后重新启动客户端")
		os.Exit(0)
	}

	return models.LoadClientConfig(path)
}

func saveConfig(path string, config *models.ClientConfig) error {
	return models.SaveClientConfig(path, config)
}
