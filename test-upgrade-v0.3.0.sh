#!/bin/bash

# v0.3.0 升级测试脚本
# 用于验证新版本的自动配置升级功能

echo "🚀 带宽监控系统 v0.3.0 升级测试"
echo "================================"

# 检查当前版本
echo "📋 当前环境检查:"
echo "- 系统: $(uname -s)"
echo "- 架构: $(uname -m)"
echo "- 时区: $(date +%Z)"
echo "- 时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 测试服务端升级
echo
echo "🔧 测试服务端升级功能:"
echo "sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)"
echo
echo "预期结果:"
echo "- ✅ 自动下载最新的v0.3.0版本二进制文件"
echo "- ✅ 自动为配置文件添加CPU告警阈值(95%)"  
echo "- ✅ 自动为配置文件添加内存告警阈值(95%)"
echo "- ✅ 保留现有的密码、端口、Telegram配置"
echo "- ✅ 启动服务后支持时区热更新"

echo
echo "🔧 测试客户端升级功能:"
echo "sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)"
echo
echo "预期结果:"
echo "- ✅ 自动下载最新的v0.3.0版本二进制文件"
echo "- ✅ 自动为配置文件补全动态阈值配置(3时段)"
echo "- ✅ 保留现有的服务器地址、密码、节点名称"
echo "- ✅ 启动服务后支持配置热重载"

echo
echo "🔧 测试一键控制脚本:"
echo "sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)"
echo
echo "预期结果:"
echo "- ✅ 自动检测网络环境，选择最优镜像源"
echo "- ✅ 提供升级选项，自动更新到v0.3.0"
echo "- ✅ 支持快捷命令: sudo bm, status bm, log bm, sudo restart bm"

echo
echo "🧪 功能验证清单:"
echo "================================"

echo "⭐ 时区热更新测试:"
echo "1. sudo timedatectl set-timezone Asia/Shanghai"
echo "2. 观察程序日志，确认无需重启即可应用新时区"
echo "3. 检查阈值计算是否使用正确的时间"

echo
echo "⭐ CPU/内存告警测试:"
echo "1. 检查配置文件中是否自动添加了cpu_percent: 95和memory_percent: 95"
echo "2. 人为制造高CPU或内存使用率"
echo "3. 确认Telegram收到对应类型的告警通知"

echo
echo "⭐ 带宽检测逻辑测试:"
echo "1. 模拟不对称带宽场景(如上行高下行低)"  
echo "2. 确认告警基于最小值(瓶颈)进行判断"
echo "3. 检查日志中的带宽计算逻辑"

echo
echo "⭐ 配置自动升级测试:"
echo "1. 备份现有配置文件"
echo "2. 手动删除config.json中的某些字段"
echo "3. 重启程序，确认自动补全默认值并保存"

echo
echo "🎯 升级命令:"
echo "使用统一脚本: sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)"  
echo "一键脚本: sudo bash <(curl -sSL https://raw.githubusercontent.com/annabeautiful1/bandwidth-monitor/main/scripts/bmctl.sh)"

echo
echo "📖 详细文档:"
echo "- 发版说明: https://github.com/annabeautiful1/bandwidth-monitor/blob/main/RELEASE_NOTES.md"
echo "- 项目README: https://github.com/annabeautiful1/bandwidth-monitor/blob/main/README.md"
echo "- 最新版本: https://github.com/annabeautiful1/bandwidth-monitor/releases/latest"