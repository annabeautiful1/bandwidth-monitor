package telegram

import (
	"fmt"
	"time"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

type Bot struct {
	api    *tgbotapi.BotAPI
	chatID int64
}

func NewBot(token string, chatID int64) (*Bot, error) {
	api, err := tgbotapi.NewBotAPI(token)
	if err != nil {
		return nil, err
	}

	return &Bot{
		api:    api,
		chatID: chatID,
	}, nil
}

func (b *Bot) SendMessage(text string) error {
	msg := tgbotapi.NewMessage(b.chatID, text)
	msg.ParseMode = tgbotapi.ModeMarkdown

	_, err := b.api.Send(msg)
	return err
}

func (b *Bot) SendBandwidthAlert(hostname string, currentMbps, thresholdMbps float64) error {
	text := fmt.Sprintf("🚨 *带宽告警*\n\n"+
		"节点: `%s`\n"+
		"当前带宽: `%.2f Mbps`\n"+
		"告警阈值: `%.2f Mbps`\n"+
		"时间: `%s`",
		hostname,
		currentMbps,
		thresholdMbps,
		time.Now().Format("2006-01-02 15:04:05"))

	return b.SendMessage(text)
}

func (b *Bot) SendBandwidthRecover(hostname string, currentMbps, thresholdMbps float64) error {
	text := fmt.Sprintf("🟢 *带宽已恢复*\n\n"+
		"节点: `%s`\n"+
		"当前带宽: `%.2f Mbps`\n"+
		"告警阈值: `%.2f Mbps`\n"+
		"时间: `%s`",
		hostname,
		currentMbps,
		thresholdMbps,
		time.Now().Format("2006-01-02 15:04:05"))
	return b.SendMessage(text)
}

func (b *Bot) SendOfflineAlert(hostname string, offlineDuration time.Duration) error {
	text := fmt.Sprintf("❌ *节点离线告警*\n\n"+
		"节点: `%s`\n"+
		"离线时长: `%.0f分钟`\n"+
		"时间: `%s`",
		hostname,
		offlineDuration.Minutes(),
		time.Now().Format("2006-01-02 15:04:05"))

	return b.SendMessage(text)
}

func (b *Bot) SendOnlineAlert(hostname string) error {
	text := fmt.Sprintf("✅ *节点重新上线*\n\n"+
		"节点: `%s`\n"+
		"时间: `%s`",
		hostname,
		time.Now().Format("2006-01-02 15:04:05"))

	return b.SendMessage(text)
}

func (b *Bot) SendTestMessage() error {
	text := "🤖 *带宽监控系统*\n\n测试消息发送成功！"
	return b.SendMessage(text)
}

// CPU告警相关方法
func (b *Bot) SendCPUAlert(hostname string, currentPercent, thresholdPercent float64) error {
	text := fmt.Sprintf("🔥 *CPU告警*\n\n"+
		"节点: `%s`\n"+
		"当前CPU: `%.2f%%`\n"+
		"告警阈值: `%.2f%%`\n"+
		"时间: `%s`",
		hostname,
		currentPercent,
		thresholdPercent,
		time.Now().Format("2006-01-02 15:04:05"))

	return b.SendMessage(text)
}

func (b *Bot) SendCPURecover(hostname string, currentPercent, thresholdPercent float64) error {
	text := fmt.Sprintf("✅ *CPU已恢复*\n\n"+
		"节点: `%s`\n"+
		"当前CPU: `%.2f%%`\n"+
		"告警阈值: `%.2f%%`\n"+
		"时间: `%s`",
		hostname,
		currentPercent,
		thresholdPercent,
		time.Now().Format("2006-01-02 15:04:05"))
	return b.SendMessage(text)
}

// 内存告警相关方法
func (b *Bot) SendMemoryAlert(hostname string, currentPercent, thresholdPercent float64) error {
	text := fmt.Sprintf("💾 *内存告警*\n\n"+
		"节点: `%s`\n"+
		"当前内存: `%.2f%%`\n"+
		"告警阈值: `%.2f%%`\n"+
		"时间: `%s`",
		hostname,
		currentPercent,
		thresholdPercent,
		time.Now().Format("2006-01-02 15:04:05"))

	return b.SendMessage(text)
}

func (b *Bot) SendMemoryRecover(hostname string, currentPercent, thresholdPercent float64) error {
	text := fmt.Sprintf("🟢 *内存已恢复*\n\n"+
		"节点: `%s`\n"+
		"当前内存: `%.2f%%`\n"+
		"告警阈值: `%.2f%%`\n"+
		"时间: `%s`",
		hostname,
		currentPercent,
		thresholdPercent,
		time.Now().Format("2006-01-02 15:04:05"))
	return b.SendMessage(text)
}
