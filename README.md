# 🚀 带宽监控系统 (Bandwidth Monitor)

一个轻量级的分布式带宽监控系统，支持实时监控服务器带宽使用情况，并在带宽异常时通过Telegram发送告警通知。

## ✨ 功能特点

- ✅ **实时监控**: 监控CPU使用率、内存使用、网络带宽等系统指标
- ✅ **智能告警**: 带宽低于阈值时自动发送Telegram通知
- ✅ **节点管理**: 自动检测节点上线/离线状态
- ✅ **轻量设计**: 极低的资源占用，适合各种规模的服务器
- ✅ **简单部署**: 一键安装脚本，5分钟完成部署
- ✅ **跨平台**: 支持Linux、Windows、macOS多平台

## 🏗️ 系统架构

```
┌─────────────────┐    HTTP API    ┌─────────────────┐
│   监控服务器     │ ◄───────────── │   被监控服务器    │
│   (Server)      │                │   (Client)      │
│                 │                │                 │
│ - 接收监控数据   │                │ - 收集系统指标   │
│ - 状态分析判断   │                │ - 定时上报数据   │
│ - 告警通知发送   │                │                 │
└─────────────────┘                └─────────────────┘
        │
        ▼
┌─────────────────┐
│   Telegram Bot  │
│   告警通知       │
└─────────────────┘
```

## 📦 快速开始

### 1. 服务端安装 (监控服务器)

在用于接收监控数据的服务器上执行：

```bash
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-server.sh | sudo bash
```

安装过程中需要配置：
- 访问密码 (客户端连接时使用)
- 监听端口 (默认8080)
- 服务器域名/IP
- Telegram机器人配置 (可选)
- 带宽告警阈值 (默认10 Mbps)
- 离线告警阈值 (默认300秒)

### 2. 客户端安装 (被监控服务器)

在需要被监控的服务器上执行：

```bash
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh | sudo bash
```

安装过程中需要配置：
- 服务器地址 (监控服务器的地址)
- 访问密码 (与服务端设置一致)
- 节点名称 (用于识别此服务器)
- 上报间隔 (默认60秒)

## 🤖 Telegram机器人配置

### 创建机器人

1. 在Telegram中搜索 `@BotFather`
2. 发送 `/newbot` 创建新机器人
3. 按提示设置机器人名称和用户名
4. 获得机器人Token (格式: `123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ`)

### 获取Chat ID

1. 将机器人添加到群组或频道 (或私聊机器人)
2. 发送任意消息给机器人
3. 访问 `https://api.telegram.org/bot<TOKEN>/getUpdates` (替换`<TOKEN>`为你的机器人Token)
4. 在返回结果中找到 `chat.id` 字段值

### 告警消息示例

```
🚨 带宽告警

节点: web-server-01
当前带宽: 8.5 Mbps
告警阈值: 10.0 Mbps  
时间: 2024-01-15 14:30:25
```

## 🔧 手动安装

### 下载二进制文件

从 [Releases页面](https://github.com/annabeautiful1/bandwidth-monitor/releases) 下载对应平台的二进制文件。

### 服务端手动安装

```bash
# 下载服务端程序
wget https://github.com/annabeautiful1/bandwidth-monitor/releases/latest/download/bandwidth-monitor-server-linux-amd64

# 设置执行权限
chmod +x bandwidth-monitor-server-linux-amd64

# 创建配置文件
cat > config.json << EOF
{
  "password": "your-password-here",
  "listen": ":8080", 
  "domain": "your-domain.com",
  "telegram": {
    "bot_token": "123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "chat_id": 123456789
  },
  "thresholds": {
    "bandwidth_mbps": 10.0,
    "offline_seconds": 300
  }
}
EOF

# 启动服务
./bandwidth-monitor-server-linux-amd64 -config=config.json
```

### 客户端手动安装

```bash
# 下载客户端程序
wget https://github.com/annabeautiful1/bandwidth-monitor/releases/latest/download/bandwidth-monitor-client-linux-amd64

# 设置执行权限  
chmod +x bandwidth-monitor-client-linux-amd64

# 创建配置文件
cat > client.json << EOF
{
  "password": "your-password-here",
  "server_url": "http://your-server.com:8080",
  "hostname": "my-server",
  "report_interval_seconds": 60
}
EOF

# 启动客户端
./bandwidth-monitor-client-linux-amd64 -config=client.json
```

## 📊 API接口

### 上报监控数据
```
POST /api/report
Content-Type: application/json

{
  "password": "your-password",
  "hostname": "server-name", 
  "timestamp": 1642248625,
  "metrics": {
    "cpu_percent": 25.5,
    "memory_used": 2147483648,
    "memory_total": 8589934592,
    "network_in_bps": 1250000,
    "network_out_bps": 625000,
    "uptime_seconds": 86400
  }
}
```

### 获取所有节点状态
```
GET /api/status

Response:
{
  "success": true,
  "message": "获取状态成功",
  "data": {
    "server1": {
      "hostname": "server1",
      "last_seen": "2024-01-15T14:30:25Z", 
      "metrics": {...},
      "is_online": true,
      "bandwidth_alerted": false
    }
  }
}
```

### 测试Telegram机器人
```
POST /api/test-telegram

Response:
{
  "success": true,
  "message": "测试消息发送成功"
}
```

## 🛠️ 配置参数说明

### 服务端配置 (config.json)

| 参数 | 描述 | 示例值 |
|------|------|--------|
| `password` | 客户端连接密码 | `"my-secret-password"` |
| `listen` | 监听地址和端口 | `":8080"` |
| `domain` | 服务器域名或IP | `"monitor.example.com"` |
| `telegram.bot_token` | Telegram机器人Token | `"123456789:ABC..."` |
| `telegram.chat_id` | 接收通知的Chat ID | `123456789` |
| `thresholds.bandwidth_mbps` | 带宽告警阈值(Mbps) | `10.0` |
| `thresholds.offline_seconds` | 离线告警阈值(秒) | `300` |

### 客户端配置 (client.json)

| 参数 | 描述 | 示例值 |
|------|------|--------|
| `password` | 连接密码(与服务端一致) | `"my-secret-password"` |
| `server_url` | 服务端地址 | `"http://monitor.example.com:8080"` |
| `hostname` | 节点名称 | `"web-server-01"` |
| `report_interval_seconds` | 上报间隔(秒) | `60` |

## 🔍 故障排查

### 查看服务状态
```bash
# 服务端
systemctl status bandwidth-monitor

# 客户端  
systemctl status bandwidth-monitor-client
```

### 查看运行日志
```bash
# 服务端日志
journalctl -u bandwidth-monitor -f

# 客户端日志
journalctl -u bandwidth-monitor-client -f
```

### 常见问题

**1. 客户端连接失败**
- 检查服务端是否正常运行
- 确认防火墙和端口配置
- 验证服务器地址和密码

**2. Telegram通知不发送**
- 验证机器人Token和Chat ID
- 检查网络连接
- 使用测试接口验证配置

**3. 服务无法启动**
- 检查配置文件格式
- 确认端口未被占用
- 查看详细错误日志

## 🚀 开发和构建

### 本地开发

```bash
# 克隆项目
git clone https://github.com/annabeautiful1/bandwidth-monitor.git
cd bandwidth-monitor

# 安装依赖
go mod tidy

# 编译服务端
go build -o bin/server ./cmd/server

# 编译客户端  
go build -o bin/client ./cmd/client

# 运行测试
go test ./...
```

### 交叉编译

```bash
# Linux AMD64
GOOS=linux GOARCH=amd64 go build -o server-linux-amd64 ./cmd/server

# Linux ARM64
GOOS=linux GOARCH=arm64 go build -o server-linux-arm64 ./cmd/server

# Windows AMD64
GOOS=windows GOARCH=amd64 go build -o server-windows-amd64.exe ./cmd/server
```

## 📄 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

## 💫 支持项目

如果这个项目对你有帮助，请给个⭐️吧！

---

**作者**: annabeautiful1  
**项目地址**: https://github.com/annabeautiful1/bandwidth-monitor