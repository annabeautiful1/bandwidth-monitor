# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个用Go语言编写的分布式带宽监控系统，包含服务端和客户端两个组件：

- **服务端**: 接收监控数据，分析带宽状态，通过Telegram发送告警
- **客户端**: 收集系统指标（CPU、内存、网络带宽），定期上报到服务端

## 构建和运行命令

```bash
# 构建服务端
go build -o bandwidth-monitor-server ./cmd/server

# 构建客户端  
go build -o bandwidth-monitor-client ./cmd/client

# 运行服务端（生成默认配置后需编辑config.json）
./bandwidth-monitor-server -config config.json

# 运行客户端（生成默认配置后需编辑client.json）
./bandwidth-monitor-client -config client.json

# 安装依赖
go mod tidy

# 格式化代码
go fmt ./...

# 运行测试
go test ./...
```

## 架构设计

### 核心模块结构
- `internal/models/`: 数据模型和配置结构定义
- `internal/server/`: 服务端HTTP API和监控逻辑
- `internal/client/`: 客户端系统指标收集和上报
- `internal/telegram/`: Telegram机器人通知功能
- `cmd/server/`: 服务端启动入口
- `cmd/client/`: 客户端启动入口

### 数据流设计
1. 客户端收集系统指标（使用gopsutil库）
2. 客户端计算当前时间的有效带宽阈值（支持动态时间段阈值）
3. 客户端通过HTTP POST上报数据到服务端
4. 服务端根据阈值判断带宽异常并触发Telegram告警
5. 服务端维护节点在线/离线状态，支持节点上线/离线通知

### 配置系统
- 服务端配置: `config.json` (密码、监听地址、Telegram配置、默认阈值)
- 客户端配置: `client.json` (密码、服务端地址、主机名、上报间隔、网卡名、阈值配置)

### 阈值策略
客户端支持两种阈值模式：
- **动态阈值**: 按时间段设置不同带宽阈值（如高峰期200Mbps，低谷期50Mbps）
- **静态阈值**: 固定带宽阈值（作为兜底配置）

## 开发注意事项

### 依赖库
- `github.com/shirou/gopsutil/v3`: 系统指标收集
- `github.com/go-telegram-bot-api/telegram-bot-api/v5`: Telegram机器人API

### 配置文件处理
- 首次运行会自动生成默认配置文件并退出
- 配置文件使用JSON格式，支持热重载（部分功能）

### 部署脚本
`scripts/` 目录包含完整的安装和管理脚本：
- `bmctl.sh`: 统一控制脚本，支持安装、更新、日志查看、配置修改
- `install-server.sh` / `install-client.sh`: 自动安装脚本
- `update-server.sh` / `update-client.sh`: 更新脚本
- `setup-client.sh`: 非交互式客户端配置脚本

### 系统服务
- 服务端服务名: `bandwidth-monitor`
- 客户端服务名: `bandwidth-monitor-client`
- 使用systemd管理，配置文件位于 `/etc/systemd/system/`

### 数据存储
系统使用内存存储节点状态，重启后状态会重置。节点离线检测基于最后上报时间。