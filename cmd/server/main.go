package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"bandwidth-monitor/internal/models"
	"bandwidth-monitor/internal/server"
	"bandwidth-monitor/internal/telegram"
)

func main() {
	configPath := flag.String("config", "config.json", "配置文件路径")
	flag.Parse()

	// 加载配置
	config, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("加载配置失败: %v", err)
	}

	// 初始化Telegram机器人
	var tgBot *telegram.Bot
	if config.Telegram.BotToken != "" {
		tgBot, err = telegram.NewBot(config.Telegram.BotToken, config.Telegram.ChatID)
		if err != nil {
			log.Fatalf("初始化Telegram机器人失败: %v", err)
		}
		log.Println("Telegram机器人初始化成功")
	}

	// 创建服务器
	srv := server.NewServer(config, tgBot)

	// 启动服务器
	go func() {
		log.Printf("服务器启动在 %s", config.Listen)
		if err := srv.Start(); err != nil {
			log.Fatalf("启动服务器失败: %v", err)
		}
	}()

	// 优雅关闭
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	log.Println("正在关闭服务器...")
	srv.Stop()
	log.Println("服务器已关闭")
}

func loadConfig(path string) (*models.ServerConfig, error) {
	// 检查配置文件是否存在
	if _, err := os.Stat(path); os.IsNotExist(err) {
		// 创建默认配置文件
		defaultConfig := &models.ServerConfig{
			Password: "your-password-here",
			Listen:   ":8080",
			Domain:   "your-domain.com",
			Telegram: models.TGConfig{
				BotToken: "",
				ChatID:   0,
			},
			Thresholds: models.Threshold{
				BandwidthMbps:  10.0,
				OfflineSeconds: 300,
			},
		}
		
		if err := saveConfig(path, defaultConfig); err != nil {
			return nil, fmt.Errorf("创建默认配置文件失败: %v", err)
		}
		
		fmt.Printf("已创建默认配置文件: %s\n", path)
		fmt.Println("请编辑配置文件后重新启动服务器")
		os.Exit(0)
	}

	return models.LoadServerConfig(path)
}

func saveConfig(path string, config *models.ServerConfig) error {
	return models.SaveServerConfig(path, config)
}