# 🚀 带宽监控系统 (Bandwidth Monitor)

一个轻量级的分布式带宽监控系统，支持实时监控服务器带宽使用情况，并在带宽异常时通过Telegram发送告警通知。

## ✨ 功能特点

- ✅ **实时监控**: 监控CPU使用率、内存使用、网络带宽等系统指标
- ✅ **智能告警**: 带宽低于阈值时自动发送Telegram通知，恢复后自动发送“带宽已恢复”
- ✅ **按节点自定义阈值**: 阈值由客户端配置与上报，每台机器可不同
- ✅ **动态阈值**: 支持按时间段设置不同带宽阈值（默认 10:00–02:00 为 200Mbps，02:00–10:00 为 50Mbps）
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
│ - 告警通知发送   │                │ - 计算并上报阈值 │
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
- 离线告警阈值 (默认300秒)

### 2. 客户端安装 (被监控服务器)

方式一：交互式安装
```bash
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh | sudo bash
```

方式二：一键非交互（与 akile 探针风格一致）
```bash
wget -O setup-client.sh https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/setup-client.sh \
  && chmod +x setup-client.sh \
  && sudo ./setup-client.sh <password> <server_url> <name> [iface] [interval]
# 示例：
# sudo ./setup-client.sh abc123 http://api.example.com:8080 CN-GZ-QZY-1G eth0 60
```

方式三：环境变量直装（可自定义阈值、时间窗）
```bash
SERVER_URL='http://api.example.com:8080' PASSWORD='abc123' HOSTNAME='CN-GZ-QZY-1G' IFACE='eth0' REPORT_INTERVAL='60' \
STATIC_BW='0' DAY_START='10:00' DAY_END='02:00' DAY_BW='200' NIGHT_START='02:00' NIGHT_END='10:00' NIGHT_BW='50' \
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh)
```

## ⚙️ 阈值配置（客户端侧）

- 阈值由客户端计算后随上报一并发送到服务端，服务端据此判断告警/恢复。
- 默认动态阈值：
  - 10:00–02:00: 200 Mbps
  - 02:00–10:00: 50 Mbps
- 可选静态阈值：将 `static_bandwidth_mbps` 设为非零值可作为兜底（当不在任何动态时间窗内时使用）。

client.json 示例：
```json
{
  "password": "abc123",
  "server_url": "http://api.example.com:8080",
  "hostname": "CN-GZ-QZY-1G",
  "report_interval_seconds": 60,
  "interface_name": "eth0",
  "threshold": {
    "static_bandwidth_mbps": 0,
    "dynamic": [
      {"start": "10:00", "end": "02:00", "bandwidth_mbps": 200},
      {"start": "02:00", "end": "10:00", "bandwidth_mbps": 50}
    ]
  }
}
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
  "metrics": { ... },
  "effective_threshold_mbps": 200
}
```

### 获取所有节点状态
```
GET /api/status
```

## 🛠️ 配置参数说明

### 客户端配置 (client.json)

| 参数 | 描述 | 示例值 |
|------|------|--------|
| `password` | 连接密码(与服务端一致) | `"my-secret-password"` |
| `server_url` | 服务端地址 | `"http://monitor.example.com:8080"` |
| `hostname` | 节点名称 | `"web-server-01"` |
| `report_interval_seconds` | 上报间隔(秒) | `60` |
| `interface_name` | 需要监控的网卡 | `"eth0"` |
| `threshold.static_bandwidth_mbps` | 静态阈值(Mbps，0 表示禁用) | `0` |
| `threshold.dynamic[]` | 动态阈值时间窗 | `[ {start,end,bandwidth_mbps} ]` |

> 说明：时间窗允许跨午夜（例如 22:00–02:00）。当时间落入多个窗口时，取首个匹配窗口的阈值；若无匹配窗口且静态阈值>0，则使用静态阈值。

## 🔍 故障排查

- 若安装后速率异常，确认 `interface_name` 已选择正确的物理网卡。
- 若未收到“恢复通知”，确认服务端与客户端版本 >= v0.1.2 且 Telegram 配置有效。

## 🚀 开发和构建
（略）

## 📄 许可证
本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献指南
欢迎提交 Issue 和 PR！