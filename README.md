# 🚀 带宽监控系统 (Bandwidth Monitor)

一个轻量级的分布式带宽监控系统，支持实时监控服务器带宽使用情况，并在带宽异常时通过Telegram发送告警通知。

## ✨ 功能特点

- ✅ **实时监控**: 监控CPU使用率、内存使用、网络带宽等系统指标
- ✅ **智能告警**: 带宽低于阈值时自动发送Telegram通知，恢复后自动发送“带宽已恢复”
- ✅ **按节点自定义阈值**: 阈值由客户端配置与上报，每台机器可不同
- ✅ **动态阈值**: 支持按时间段设置不同带宽阈值（默认 10:00–02:00 为 200Mbps，02:00–10:00 为 50Mbps）
- ✅ **首次上线通知**: 节点首次被发现或离线后重新上线都会推送
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
```bash
# GitHub
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-server.sh | sudo bash
# 镜像（jsDelivr）
curl -sSL https://cdn.jsdelivr.net/gh/annabeautiful1/bandwidth-monitor/scripts/install-server.sh | sudo bash
```

### 2. 客户端安装 (被监控服务器)
- 交互式安装
```bash
# GitHub
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh | sudo bash
# 镜像（jsDelivr）
curl -sSL https://cdn.jsdelivr.net/gh/annabeautiful1/bandwidth-monitor/scripts/install-client.sh | sudo bash
```
- 一键非交互（与 akile 探针风格一致）
```bash
wget -O setup-client.sh https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/setup-client.sh \
  && chmod +x setup-client.sh \
  && sudo ./setup-client.sh <password> <server_url> <name> [iface] [interval]
# 镜像
wget -O setup-client.sh https://cdn.jsdelivr.net/gh/annabeautiful1/bandwidth-monitor/scripts/setup-client.sh \
  && chmod +x setup-client.sh \
  && sudo ./setup-client.sh <password> <server_url> <name> [iface] [interval]
```
- 环境变量直装（可自定义阈值、时间窗）
```bash
SERVER_URL='http://api.example.com:8080' PASSWORD='abc123' HOSTNAME='CN-GZ-QZY-1G' IFACE='eth0' REPORT_INTERVAL='60' \
STATIC_BW='0' DAY_START='10:00' DAY_END='02:00' DAY_BW='200' NIGHT_START='02:00' NIGHT_END='10:00' NIGHT_BW='50' \
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh)
```

### 3. 一键更新（升级到最新Release）
- 服务端更新
```bash
# GitHub
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-server.sh)
# 镜像
bash <(curl -sSL https://cdn.jsdelivr.net/gh/annabeautiful1/bandwidth-monitor/scripts/update-server.sh)
```
- 客户端更新
```bash
# GitHub
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-client.sh)
# 镜像
bash <(curl -sSL https://cdn.jsdelivr.net/gh/annabeautiful1/bandwidth-monitor/scripts/update-client.sh)
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
（略）

## 🛠️ 配置参数说明
（略）

## 🔍 故障排查
- 若安装后速率异常，确认 `interface_name` 已选择正确的物理网卡。
- 若未收到“上线/离线/恢复”通知，先调用服务端测试接口：
```bash
curl -X POST http://<server>:<port>/api/test-telegram
```

## 📄 许可证
本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献指南
欢迎提交 Issue 和 PR！