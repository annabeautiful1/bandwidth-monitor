# 🚀 带宽监控系统 (Bandwidth Monitor)

[![Release](https://img.shields.io/github/v/release/annabeautiful1/bandwidth-monitor)](https://github.com/annabeautiful1/bandwidth-monitor/releases)
[![Go Version](https://img.shields.io/github/go-mod/go-version/annabeautiful1/bandwidth-monitor)](https://github.com/annabeautiful1/bandwidth-monitor)
[![License](https://img.shields.io/github/license/annabeautiful1/bandwidth-monitor)](https://github.com/annabeautiful1/bandwidth-monitor/blob/main/LICENSE)

一个轻量级的分布式带宽监控系统，支持实时监控服务器带宽、CPU、内存使用情况，并在异常时通过Telegram发送告警通知。

## 🎯 快速开始

### 📱 交互式管理（推荐）
```bash
# 一键启动管理面板
sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)

# 中国大陆加速镜像
sudo bash <(curl -sSL https://ghfast.top/https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)
```

交互面板提供：
- 🖥️ **服务端管理**: 安装/更新/重启监控服务器
- 💻 **客户端管理**: 批量部署和管理被监控节点
- ⚙️ **配置编辑**: 可视化配置三时段动态阈值
- 📊 **实时状态**: 显示所有节点版本和运行状态
- 🕐 **时区设置**: 一键设置北京时间
- 🔧 **快捷命令**: 自动安装 `bm`, `status bm`, `log bm` 等快捷命令

### ⚡ 客户端一键安装（非交互）
```bash
# 基础安装（密码 服务器地址 主机名）
sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh) \
  abc123 \
  http://your-server.com:8080 \
  CN-BJ-WEB-01

# 完整配置（+ 网卡名 上报间隔）
sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh) \
  abc123 \
  http://your-server.com:8080 \
  CN-BJ-WEB-01 \
  eth0 \
  30
```

> 💡 **非交互模式说明**：
> - `密码`: 客户端连接服务器的认证密码
> - `服务器地址`: 监控服务器的完整URL
> - `主机名`: 节点显示名称
> - `网卡名`: 可选，留空自动检测
> - `上报间隔`: 可选，默认60秒，范围10-3600秒

### 🚀 批量部署示例
```bash
# 批量部署多台服务器
servers=("192.168.1.10" "192.168.1.11" "192.168.1.12")
for i in "${!servers[@]}"; do
  ssh root@${servers[$i]} "bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh) abc123 http://monitor.company.com:8080 WEB-0$((i+1))"
done
```

## ✨ 功能特点

- ✅ **实时监控**: 监控CPU使用率、内存使用、网络带宽等系统指标
- ✅ **智能告警**: 带宽低于阈值时自动发送Telegram通知，恢复后自动发送“带宽已恢复”
- ✅ **按节点自定义阈值**: 阈值由客户端配置与上报，每台机器可不同
- ✅ **动态阈值**: 支持按时间段设置不同带宽阈值（默认 22:00–02:00 为高峰期 200Mbps，02:00–09:00 为低谷期 50Mbps，09:00–22:00 为平峰期 100Mbps）
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
- GitHub 源
```bash
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-server.sh | sudo bash
```
- 中国大陆镜像（ghfast）
```bash
curl -sSL https://ghfast.top/https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-server.sh | sudo bash
```

### 2. 客户端安装 (被监控服务器)
- GitHub 源（交互式）
```bash
curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh | sudo bash
```
- 中国大陆镜像（交互式）
```bash
curl -sSL https://ghfast.top/https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/install-client.sh | sudo bash
```
- GitHub 源（一键非交互）
```bash
wget -O setup-client.sh https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/setup-client.sh && chmod +x setup-client.sh
```
```bash
sudo ./setup-client.sh <password> <server_url> <name> [iface] [interval]
```
- 中国大陆镜像（一键非交互）
```bash
wget -O setup-client.sh https://ghfast.top/https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/setup-client.sh && chmod +x setup-client.sh
```
```bash
sudo ./setup-client.sh <password> <server_url> <name> [iface] [interval]
```
**参数说明**
- `password`：与服务端配置一致的访问密码（客户端上报校验用）。
- `server_url`：服务端 HTTP/HTTPS 地址，格式如 `http://domain:port` 或 `https://domain:port`。
- `name`：节点名称（显示在告警与状态中）。
- `iface`（可选）：要监控的网卡名，如 `eth0`、`ens18`。留空则自动选择第一个非回环/非虚拟网卡。
- `interval`（可选）：上报间隔（秒），默认 `60`（脚本里最小 10 秒）。

示例：
```bash
sudo ./setup-client.sh abc123 http://api.example.com:8080 CN-GZ-QZY-1G eth0 60
```

### 3. 一键更新（升级到最新Release）
- GitHub 源
```bash
# 服务端
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-server.sh)
```
```bash
# 客户端
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-client.sh)
```
- 中国大陆镜像
```bash
# 服务端
bash <(curl -sSL https://ghfast.top/https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-server.sh)
```
```bash
# 客户端
bash <(curl -sSL https://ghfast.top/https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-client.sh)
```

> 提升发布包下载速度：脚本支持通过 `RELEASE_MIRROR` 指定 Release 下载镜像前缀（如 `https://ghfast.top/`）。可在 https://ghproxy.link/ 获取最新可用镜像地址。示例：
```bash
RELEASE_MIRROR=https://ghfast.top/ \
bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/update-client.sh)
```

## ⚙️ 阈值配置（客户端侧）
- 阈值由客户端计算后随上报一并发送到服务端，服务端据此判断告警/恢复。
- 默认动态阈值：
  - 22:00–02:00: 200 Mbps（高峰期）
  - 02:00–09:00: 50 Mbps（低谷期）
  - 09:00–22:00: 100 Mbps（平峰期）
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
      {"start": "22:00", "end": "02:00", "bandwidth_mbps": 200},
      {"start": "02:00", "end": "09:00", "bandwidth_mbps": 50},
      {"start": "09:00", "end": "22:00", "bandwidth_mbps": 100}
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
- 若未收到"上线/离线/恢复"通知，先调用服务端测试接口：
```bash
curl -X POST http://<server>:<port>/api/test-telegram
```

## ⚡ 快捷命令（自动安装）

首次运行 bmctl.sh 控制脚本时，会自动安装简化命令：
- `sudo bm` - 打开控制面板
- `status bm` - 查看服务状态  
- `log bm` - 查看日志
- `sudo restart bm` - 重启服务

无需单独安装，运行一键控制脚本后即可使用这些快捷命令。

## 📄 许可证
本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献指南
欢迎提交 Issue 和 PR！