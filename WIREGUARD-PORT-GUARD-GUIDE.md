# WireGuard端口防封系统使用指南

## 🛡️ 功能概述

WireGuard端口防封系统是一个智能的端口管理解决方案，专门解决WireGuard端口被随机封锁的问题。

### 🚀 核心功能

1. **智能端口检测** - 自动检测端口是否被封锁
2. **自动端口更换** - 检测到封锁后自动更换到可用端口
3. **客户端配置自动更新** - 自动更新所有客户端配置文件
4. **定时监控服务** - 后台持续监控端口状态
5. **多端口轮换策略** - 智能选择最优端口
6. **配置自动备份** - 每次更换前自动备份配置

## 📋 使用方法

### 方法一：集成在All-in-One脚本中

```bash
# 运行All-in-One脚本
sudo ./wireguard-all-in-one.sh

# 选择 "9. 端口防封管理"
```

### 方法二：使用独立脚本

```bash
# 设置执行权限
chmod +x wireguard-port-guard.sh

# 运行脚本
sudo ./wireguard-port-guard.sh
```

## 🔧 功能详解

### 1. 检查当前端口状态

检查项目包括：
- ✅ 本地端口监听状态
- ✅ 防火墙规则配置
- ✅ WireGuard连接状态
- ✅ 外部连通性测试

```bash
# 命令行方式
sudo ./wireguard-port-guard.sh check
```

### 2. 手动更换端口

支持功能：
- 📋 推荐端口列表
- 🎯 自定义端口输入
- 🔍 端口占用检查
- ⚡ 一键更换

推荐端口列表：
- `51821-51829` - WireGuard常用端口
- `2408` - 非标准端口
- `4096` - 高位端口
- `8080` - HTTP代理端口
- `9999` - 通用端口

### 3. 自动监控服务

监控特性：
- ⏰ 每5分钟检查一次
- 🎯 连续3次失败后触发更换
- 📝 详细日志记录
- 🔄 自动重启保护

```bash
# 启用监控
sudo ./wireguard-port-guard.sh install

# 查看监控状态
systemctl status wireguard-port-guard

# 查看监控日志
journalctl -u wireguard-port-guard -f
```

### 4. 客户端配置自动更新

更新内容：
- 🔄 自动更新Endpoint端口
- 📱 重新生成二维码
- 💾 备份原始配置
- 📋 生成更新通知

## ⚙️ 配置选项

### 基础配置

```bash
# 可用端口列表
AVAILABLE_PORTS=(51820 51821 51822 51823 51824 51825 2408 4096 8080 9999)

# 检查间隔 (秒)
CHECK_INTERVAL=300

# 失败阈值
FAIL_THRESHOLD=3
```

### 高级配置

```bash
# 启用端口伪装
ENABLE_PORT_MASQUERADE=false

# 启用多端口模式
ENABLE_MULTI_PORT=false

# 启用通知功能
ENABLE_NOTIFICATIONS=false
NOTIFICATION_EMAIL="admin@example.com"
WEBHOOK_URL="https://hooks.slack.com/..."
```

## 🔍 故障排查

### 常见问题

#### 1. 端口检测误报
**现象**：端口实际正常但被误判为封锁
**解决**：
- 检查网络连接
- 调整失败阈值
- 查看详细日志

#### 2. 客户端配置未更新
**现象**：端口更换后客户端无法连接
**解决**：
- 重新下载配置文件
- 扫描新的二维码
- 手动修改Endpoint端口

#### 3. 监控服务异常
**现象**：监控服务频繁重启或停止
**解决**：
```bash
# 查看服务状态
systemctl status wireguard-port-guard

# 查看详细日志
journalctl -u wireguard-port-guard --no-pager

# 重启服务
systemctl restart wireguard-port-guard
```

### 日志分析

```bash
# 查看端口防封日志
tail -f /var/log/wireguard-port-guard.log

# 查看系统服务日志
journalctl -u wireguard-port-guard -f

# 查看WireGuard日志
journalctl -u wg-quick@wg0 -f
```

## 📊 监控指标

### 端口状态指标

- **连通性成功率** - 外部连通性测试成功百分比
- **活跃握手数** - 当前活跃的客户端连接数
- **端口监听状态** - 端口是否正常监听
- **防火墙规则状态** - 防火墙规则是否正确配置

### 判断标准

| 成功率 | 状态 | 建议操作 |
|--------|------|----------|
| ≥80% | 🟢 良好 | 继续监控 |
| 50-79% | 🟡 一般 | 加强监控 |
| <50% | 🔴 异常 | 立即更换端口 |

## 🔐 安全建议

### 端口选择策略

1. **避免常用端口** - 不使用22、80、443等常见端口
2. **使用高位端口** - 优先选择1024以上端口
3. **端口分散** - 不要集中使用连续端口
4. **定期轮换** - 定期主动更换端口

### 配置安全

1. **配置文件权限** - 确保配置文件权限为600
2. **定期备份** - 启用自动备份功能
3. **日志监控** - 定期检查日志异常
4. **客户端管理** - 及时删除不用的客户端

## 🚨 应急处理

### 紧急端口更换

如果发现端口被封锁，可以立即手动更换：

```bash
# 快速更换端口
sudo ./wireguard-port-guard.sh change

# 或使用All-in-One脚本
sudo ./wireguard-all-in-one.sh
# 选择 "9. 端口防封管理" → "2. 手动更换端口"
```

### 恢复备份配置

如果更换端口后出现问题：

```bash
# 查看备份文件
ls -la /etc/wireguard/backups/

# 恢复备份 (手动操作)
cd /etc/wireguard
tar -xzf backups/wg_backup_YYYYMMDD_HHMMSS.tar.gz
systemctl restart wg-quick@wg0
```

## 📞 技术支持

如果遇到问题：

1. **查看日志** - 检查详细的错误日志
2. **检查网络** - 确认基础网络连通性
3. **验证配置** - 检查WireGuard配置文件
4. **重启服务** - 尝试重启相关服务
5. **提交Issue** - 在GitHub项目中提交问题报告

---

**注意**：端口防封功能需要root权限运行，请确保在安全的环境中使用。
