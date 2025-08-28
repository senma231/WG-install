# WireGuard 快捷命令总结

## 🚀 一键安装命令

### 下载并运行一体化脚本
```bash
# 一键下载、授权、运行
wget https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh && chmod +x wireguard-all-in-one.sh && sudo ./wireguard-all-in-one.sh
```

### 下载并运行Windows客户端优化脚本
```bash
# 一键下载、授权、运行Windows优化
wget https://raw.githubusercontent.com/senma231/WG-install/main/windows-client-optimization.sh && chmod +x windows-client-optimization.sh && sudo ./windows-client-optimization.sh
```

## 📋 分步骤命令

### 1. 一体化脚本 (wireguard-all-in-one.sh)

#### 下载脚本
```bash
wget https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh
```

#### 设置执行权限
```bash
chmod +x wireguard-all-in-one.sh
```

#### 运行脚本
```bash
# 正常运行
sudo ./wireguard-all-in-one.sh

# 调试模式运行
DEBUG_MODE=true sudo ./wireguard-all-in-one.sh

# 显示帮助
./wireguard-all-in-one.sh --help

# 显示版本
./wireguard-all-in-one.sh --version
```

### 2. Windows客户端优化脚本

#### 下载脚本
```bash
wget https://raw.githubusercontent.com/senma231/WG-install/main/windows-client-optimization.sh
```

#### 设置执行权限
```bash
chmod +x windows-client-optimization.sh
```

#### 运行优化脚本
```bash
sudo ./windows-client-optimization.sh
```

## 🎯 功能快捷命令

### 🆕 新增Windows客户端智能配置

一体化脚本现在支持Windows客户端的智能识别和优化配置：

#### Windows客户端特性
- **自动优化配置**: MTU=1420, 优化的DNS设置
- **流量模式选择**: 全局代理 vs 内网访问
- **Windows专用优化**: PersistentKeepalive=25
- **智能配置文件命名**:
  - `客户端名-global.conf` (全局代理)
  - `客户端名-internal.conf` (内网访问)

#### 使用流程
1. 运行一体化脚本: `sudo ./wireguard-all-in-one.sh`
2. 选择 "2. 添加客户端"
3. 选择 "1. Windows客户端"
4. 选择流量模式：
   - **全局代理**: 所有流量通过VPN
   - **内网访问**: 仅访问服务端内网资源

### 一体化脚本功能菜单
运行 `sudo ./wireguard-all-in-one.sh` 后的选项：

```
1. 安装WireGuard服务端     # 完整安装WireGuard服务
2. 添加客户端              # 智能添加客户端配置（支持Windows优化）
   ├─ Windows客户端        # 包含MTU、DNS、流量模式优化
   │  ├─ 全局代理模式      # 所有流量通过VPN
   │  └─ 内网访问模式      # 仅访问服务端内网资源
   └─ 其他客户端          # Linux/macOS/Android/iOS等
3. 删除客户端              # 删除现有客户端
4. 列出所有客户端          # 查看所有客户端状态和类型
5. 显示服务状态            # 查看WireGuard运行状态
6. 网络诊断               # 全面的网络连通性检测
7. 卸载WireGuard          # 完全卸载WireGuard
0. 退出                   # 退出脚本
```

### Windows客户端管理命令

#### 生成Windows客户端配置
```bash
# 生成全局代理配置（所有流量通过VPN）
wg-windows-client generate laptop full

# 生成内网访问配置（仅访问服务端内网）
wg-windows-client generate office partial

# 生成指定名称的客户端配置
wg-windows-client generate <客户端名称> <模式>
```

#### 客户端配置模式说明
- **full**: 全局代理模式，所有流量通过VPN
- **partial**: 内网访问模式，仅内网流量通过VPN

## 🔧 系统管理命令

### WireGuard服务管理
```bash
# 查看服务状态
sudo systemctl status wg-quick@wg0

# 启动服务
sudo systemctl start wg-quick@wg0

# 停止服务
sudo systemctl stop wg-quick@wg0

# 重启服务
sudo systemctl restart wg-quick@wg0

# 启用开机自启
sudo systemctl enable wg-quick@wg0

# 禁用开机自启
sudo systemctl disable wg-quick@wg0
```

### 查看WireGuard状态
```bash
# 查看WireGuard接口状态
sudo wg show

# 查看详细连接信息
sudo wg show all

# 查看指定接口
sudo wg show wg0
```

### 网络诊断命令
```bash
# 检查端口监听
sudo ss -ulpn | grep 51820

# 检查防火墙规则
sudo iptables -L | grep 51820

# 测试网络连通性
ping -c 3 8.8.8.8

# 检查IP转发
cat /proc/sys/net/ipv4/ip_forward

# 查看网络接口
ip addr show wg0
```

## 📁 文件路径快捷命令

### 查看配置文件
```bash
# 查看服务端配置
sudo cat /etc/wireguard/wg0.conf

# 查看客户端配置目录
ls -la /etc/wireguard/clients/

# 查看指定客户端配置
sudo cat /etc/wireguard/clients/<客户端名称>.conf

# 查看Windows客户端配置模板
ls -la /etc/wireguard/templates/
```

### 备份和恢复
```bash
# 手动备份配置
sudo tar -czf ~/wireguard-backup-$(date +%Y%m%d).tar.gz /etc/wireguard/

# 查看备份文件
ls -la ~/wireguard-backup-*.tar.gz

# 恢复配置（示例）
sudo tar -xzf ~/wireguard-backup-20231201.tar.gz -C /
```

## 🔍 故障排查快捷命令

### 日志查看
```bash
# 查看WireGuard服务日志
sudo journalctl -u wg-quick@wg0 -f

# 查看最近的日志
sudo journalctl -u wg-quick@wg0 --since "1 hour ago"

# 查看系统日志
sudo tail -f /var/log/syslog | grep wireguard
```

### 网络测试
```bash
# 测试服务端连通性
ping -c 3 <服务端IP>

# 测试VPN内网连通性
ping -c 3 10.66.0.1

# 测试DNS解析
nslookup google.com

# 检查路由表
ip route show

# 测试端口连通性
telnet <服务端IP> 51820
```

### 性能测试
```bash
# 检查系统负载
top

# 检查内存使用
free -h

# 检查磁盘使用
df -h

# 检查网络流量
sudo iftop -i wg0
```

## 🛠️ 维护命令

### 更新脚本
```bash
# 更新一体化脚本
wget -O wireguard-all-in-one.sh https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh && chmod +x wireguard-all-in-one.sh

# 更新Windows优化脚本
wget -O windows-client-optimization.sh https://raw.githubusercontent.com/senma231/WG-install/main/windows-client-optimization.sh && chmod +x windows-client-optimization.sh
```

### 系统更新
```bash
# Ubuntu/Debian 更新WireGuard
sudo apt update && sudo apt upgrade wireguard

# CentOS/RHEL 更新WireGuard
sudo yum update wireguard-tools
# 或
sudo dnf update wireguard-tools
```

### 清理命令
```bash
# 清理临时文件
sudo rm -f /tmp/wg-*

# 清理旧的备份文件（保留最近7天）
find ~/wireguard-backup-*.tar.gz -mtime +7 -delete

# 清理日志文件
sudo journalctl --vacuum-time=7d
```

## 🔐 安全管理命令

### 密钥管理
```bash
# 生成新的密钥对
wg genkey | tee private.key | wg pubkey > public.key

# 查看私钥
sudo cat /etc/wireguard/wg0.conf | grep PrivateKey

# 重新生成服务端密钥（需要重新配置所有客户端）
# 注意：这会断开所有现有连接
sudo systemctl stop wg-quick@wg0
# 然后重新运行安装脚本
```

### 防火墙管理
```bash
# 查看UFW状态
sudo ufw status

# 查看iptables规则
sudo iptables -L -n

# 查看NAT规则
sudo iptables -t nat -L -n

# 重新加载防火墙规则
sudo systemctl restart wg-quick@wg0
```

## 📊 监控命令

### 实时监控
```bash
# 实时查看连接状态
watch -n 2 'sudo wg show'

# 实时查看网络流量
sudo iftop -i wg0

# 实时查看系统资源
htop

# 实时查看日志
sudo journalctl -u wg-quick@wg0 -f
```

### 统计信息
```bash
# 查看客户端数量
ls /etc/wireguard/clients/*.conf 2>/dev/null | wc -l

# 查看在线客户端数量
sudo wg show | grep -c "peer:"

# 查看流量统计
sudo wg show all dump
```

## 🚨 紧急命令

### 紧急停止
```bash
# 立即停止WireGuard服务
sudo systemctl stop wg-quick@wg0

# 删除WireGuard网络接口
sudo ip link delete wg0
```

### 紧急恢复
```bash
# 重启WireGuard服务
sudo systemctl restart wg-quick@wg0

# 如果服务启动失败，检查配置
sudo wg-quick up wg0
```

### 完全重置
```bash
# 停止服务
sudo systemctl stop wg-quick@wg0
sudo systemctl disable wg-quick@wg0

# 备份配置
sudo cp -r /etc/wireguard /root/wireguard-backup-emergency

# 删除配置
sudo rm -rf /etc/wireguard

# 重新运行安装脚本
sudo ./wireguard-all-in-one.sh
```

## 📞 快速帮助

### 获取帮助
```bash
# 脚本帮助
./wireguard-all-in-one.sh --help
./windows-client-optimization.sh --help

# WireGuard命令帮助
wg --help
wg-quick --help

# 系统服务帮助
systemctl --help
```

### 版本信息
```bash
# 脚本版本
./wireguard-all-in-one.sh --version

# WireGuard版本
wg --version

# 系统版本
cat /etc/os-release
```

---

## 🎯 常用命令组合

### 完整安装流程
```bash
# 1. 下载并安装WireGuard服务端
wget https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh && chmod +x wireguard-all-in-one.sh && sudo ./wireguard-all-in-one.sh

# 2. 优化服务端支持Windows客户端
wget https://raw.githubusercontent.com/senma231/WG-install/main/windows-client-optimization.sh && chmod +x windows-client-optimization.sh && sudo ./windows-client-optimization.sh

# 3. 生成Windows客户端配置
wg-windows-client generate laptop full
```

### 日常维护流程
```bash
# 检查服务状态
sudo systemctl status wg-quick@wg0

# 查看连接状态
sudo wg show

# 查看日志
sudo journalctl -u wg-quick@wg0 --since "1 hour ago"

# 备份配置
sudo tar -czf ~/wireguard-backup-$(date +%Y%m%d).tar.gz /etc/wireguard/
```

**保存此文档以便快速查找所需命令！** 📚
