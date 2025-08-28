# WireGuard防火墙和NAT配置指南

## 🛡️ 防火墙和NAT自动检测与配置

All-in-One脚本现在包含完整的防火墙和NAT自动检测与配置功能，确保WireGuard和端口转发正常工作。

## 🚀 新增功能

### 1. 智能防火墙检测
- **自动检测防火墙类型**: UFW、firewalld、iptables
- **端口开放状态检查**: 检查WireGuard和转发端口是否开放
- **自动配置规则**: 根据检测结果自动添加防火墙规则

### 2. NAT配置检查
- **IP转发状态检查**: 验证内核IP转发是否启用
- **MASQUERADE规则检查**: 确保NAT转换正确配置
- **WireGuard接口转发**: 检查WireGuard接口的转发规则

### 3. 云服务商安全组检测
- **自动识别云服务商**: 阿里云、腾讯云、AWS、Google Cloud
- **安全组配置提醒**: 提供具体的控制台配置指导
- **端口开放建议**: 针对不同云服务商的端口配置建议

## 📋 使用方法

### 快速检查
```bash
# 运行All-in-One脚本
sudo ./wireguard-all-in-one.sh

# 选择 "7. 防火墙和NAT检查"
```

### 自动修复
脚本会自动检测问题并提供修复选项：
- 自动开放WireGuard端口
- 自动开放端口转发规则的端口
- 自动配置NAT规则
- 自动启用IP转发

## 🔧 支持的防火墙类型

### 1. UFW (Ubuntu Firewall)
```bash
# 检测命令
ufw status

# 自动配置
ufw allow 51820/udp comment "WireGuard VPN"
ufw allow 13389/tcp comment "Port Forward RDP"
```

### 2. firewalld (CentOS/RHEL/Fedora)
```bash
# 检测命令
firewall-cmd --state

# 自动配置
firewall-cmd --permanent --add-port=51820/udp
firewall-cmd --permanent --add-port=13389/tcp
firewall-cmd --reload
```

### 3. iptables (通用)
```bash
# 检测命令
iptables -L INPUT

# 自动配置
iptables -I INPUT -p udp --dport 51820 -j ACCEPT
iptables -I INPUT -p tcp --dport 13389 -j ACCEPT
```

## 🌐 NAT配置详解

### IP转发配置
```bash
# 临时启用
echo 1 > /proc/sys/net/ipv4/ip_forward

# 永久启用
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
```

### MASQUERADE规则
```bash
# 添加NAT规则
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# WireGuard接口转发
iptables -I FORWARD -i wg0 -j ACCEPT
iptables -I FORWARD -o wg0 -j ACCEPT
```

## ☁️ 云服务商安全组配置

### 阿里云ECS
1. **登录阿里云控制台**
2. **进入ECS实例管理**
3. **点击"安全组" → "配置规则"**
4. **添加入方向规则**：
   - 协议类型: UDP
   - 端口范围: 51820/51820
   - 授权对象: 0.0.0.0/0
   - 描述: WireGuard VPN

### 腾讯云CVM
1. **登录腾讯云控制台**
2. **进入云服务器CVM**
3. **点击"安全组" → "修改规则"**
4. **添加入站规则**：
   - 类型: 自定义
   - 协议端口: UDP:51820
   - 来源: 0.0.0.0/0
   - 策略: 允许

### AWS EC2
1. **登录AWS控制台**
2. **进入EC2 Dashboard**
3. **点击"Security Groups"**
4. **编辑Inbound Rules**：
   - Type: Custom UDP
   - Port Range: 51820
   - Source: 0.0.0.0/0
   - Description: WireGuard VPN

### Google Cloud Platform
1. **登录Google Cloud Console**
2. **进入VPC网络 → 防火墙**
3. **创建防火墙规则**：
   - 名称: allow-wireguard
   - 方向: 入站
   - 协议和端口: UDP 51820
   - 来源IP范围: 0.0.0.0/0

## 🔍 故障排查

### 常见问题检查清单

#### 1. WireGuard无法连接
```bash
# 检查服务状态
sudo systemctl status wg-quick@wg0

# 检查端口监听
sudo ss -ulpn | grep 51820

# 检查防火墙规则
sudo iptables -L INPUT | grep 51820
```

#### 2. 端口转发无法访问
```bash
# 检查NAT规则
sudo iptables -t nat -L PREROUTING

# 检查转发规则
sudo iptables -L FORWARD

# 检查IP转发
cat /proc/sys/net/ipv4/ip_forward
```

#### 3. 客户端连接后无法上网
```bash
# 检查MASQUERADE规则
sudo iptables -t nat -L POSTROUTING

# 检查DNS设置
nslookup google.com

# 检查路由
ip route show
```

### 自动诊断命令
```bash
# 运行完整的防火墙和NAT检查
sudo ./wireguard-all-in-one.sh
# 选择 "7. 防火墙和NAT检查"

# 查看详细的检查结果
# 脚本会自动检测并报告所有问题
```

## 📊 检查报告示例

```
执行全面的防火墙和NAT检查...

1. 防火墙状态检查
检测到的防火墙类型: ufw

2. WireGuard端口检查
✓ WireGuard端口 51820/UDP 已在防火墙中开放

3. 端口转发规则检查
✓ 转发端口 13389/TCP 已在防火墙中开放
✓ 转发端口 2222/TCP 已在防火墙中开放

4. NAT配置检查
✓ NAT配置正常

5. 云服务商安全组检查
⚠ 检测到阿里云ECS
  请在阿里云控制台检查安全组规则：
  1. 登录阿里云控制台
  2. 进入ECS实例管理
  3. 点击'安全组' → '配置规则'
  4. 添加入方向规则，开放WireGuard端口 51820/UDP

✓ 所有防火墙和NAT配置检查通过！
```

## 🔧 手动配置命令

### 完整的防火墙配置
```bash
# UFW配置
sudo ufw allow 51820/udp comment "WireGuard VPN"
sudo ufw allow 13389/tcp comment "RDP Forward"
sudo ufw allow 2222/tcp comment "SSH Forward"

# firewalld配置
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --permanent --add-port=13389/tcp
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --reload

# iptables配置
sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 13389 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 2222 -j ACCEPT
```

### 完整的NAT配置
```bash
# 启用IP转发
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

# 配置NAT规则
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -I FORWARD -i wg0 -j ACCEPT
sudo iptables -I FORWARD -o wg0 -j ACCEPT

# 保存规则
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

## 🎯 最佳实践

### 1. 安全配置
- ✅ 仅开放必要的端口
- ✅ 使用非标准端口（如RDP使用13389而不是3389）
- ✅ 定期检查防火墙规则
- ✅ 监控异常连接

### 2. 性能优化
- ✅ 使用高效的防火墙规则
- ✅ 避免重复的iptables规则
- ✅ 定期清理无用规则
- ✅ 监控网络性能

### 3. 维护建议
- ✅ 定期运行防火墙检查
- ✅ 备份防火墙配置
- ✅ 记录所有配置变更
- ✅ 测试故障恢复流程

## 🚨 重要提醒

### 云服务商安全组是关键！
**90%的连接问题都是由于云服务商的安全组未正确配置导致的**

即使服务器本地防火墙配置正确，如果云服务商的安全组没有开放相应端口，外部仍然无法访问。

### 检查优先级
1. **云服务商安全组** - 最重要！
2. **服务器本地防火墙** - 其次重要
3. **NAT和路由配置** - 基础配置
4. **客户端防火墙** - 客户端问题

## 📞 技术支持

如果自动检查和修复仍无法解决问题：

1. **运行完整诊断**：选择菜单中的"防火墙和NAT检查"
2. **查看详细日志**：注意检查报告中的警告和错误
3. **手动验证配置**：使用提供的手动配置命令
4. **检查云服务商控制台**：确认安全组配置正确

---

## 🎉 总结

新的防火墙和NAT自动检测功能让WireGuard配置变得更加简单和可靠：

- 🔍 **智能检测** - 自动识别防火墙类型和配置问题
- 🛠️ **自动修复** - 一键解决常见配置问题  
- ☁️ **云服务商支持** - 针对主流云服务商的专门指导
- 📊 **详细报告** - 清晰的检查结果和修复建议

**立即体验**：
```bash
sudo ./wireguard-all-in-one.sh
# 选择 "7. 防火墙和NAT检查"
```
