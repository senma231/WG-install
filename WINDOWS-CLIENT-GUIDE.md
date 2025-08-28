# Windows客户端配置指南

## 🎯 服务端优化

你的WireGuard服务端已经安装完成，现在需要针对Windows客户端进行优化。

### 1. 运行服务端优化脚本

```bash
# 下载优化脚本
wget https://raw.githubusercontent.com/senma231/WG-install/main/windows-client-optimization.sh

# 设置执行权限
chmod +x windows-client-optimization.sh

# 运行优化脚本
sudo ./windows-client-optimization.sh
```

### 2. 优化内容

服务端优化脚本会进行以下优化：

#### 🔧 系统内核参数优化
- **网络缓冲区优化** - 提高数据传输效率
- **UDP参数优化** - WireGuard使用UDP协议
- **延迟优化** - 减少网络延迟
- **连接跟踪优化** - 提高连接稳定性

#### 🛡️ 防火墙规则优化
- **连接状态跟踪** - 优化已建立连接的处理
- **NAT规则优化** - 改善网络地址转换
- **DDoS防护** - 防止恶意连接攻击

#### 🌐 网络接口优化
- **队列长度优化** - 提高网络吞吐量
- **网卡特性启用** - 启用硬件加速功能

## 📱 Windows客户端安装

### 1. 下载WireGuard客户端

#### 方法一：官方网站下载
访问：https://www.wireguard.com/install/
下载Windows版本

#### 方法二：使用winget安装
```powershell
# 以管理员身份运行PowerShell
winget install WireGuard.WireGuard
```

#### 方法三：Microsoft Store
在Microsoft Store搜索"WireGuard"并安装

### 2. 生成客户端配置

在服务端运行以下命令生成Windows客户端配置：

```bash
# 生成全局代理配置（所有流量通过VPN）
wg-windows-client generate laptop full

# 生成内网访问配置（仅访问服务端内网资源）
wg-windows-client generate office partial
```

## 🔧 两种连接模式

### 模式一：全局代理 (full)
**适用场景**：需要完全的网络隐私保护，访问被限制的网站

**特点**：
- ✅ 所有网络流量都通过VPN
- ✅ 完全的IP地址隐藏
- ✅ 绕过地理限制
- ❌ 可能影响本地网络访问速度

**配置示例**：
```ini
[Interface]
PrivateKey = <客户端私钥>
Address = 10.66.0.2/24
DNS = 223.5.5.5, 119.29.29.29, 8.8.8.8
MTU = 1420

[Peer]
PublicKey = <服务端公钥>
Endpoint = <服务端IP>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### 模式二：内网访问 (partial)
**适用场景**：远程办公，访问公司内网资源

**特点**：
- ✅ 仅内网流量通过VPN
- ✅ 本地网络访问不受影响
- ✅ 更好的网络性能
- ❌ 不提供完全的隐私保护

**配置示例**：
```ini
[Interface]
PrivateKey = <客户端私钥>
Address = 10.66.0.2/24
DNS = 223.5.5.5, 119.29.29.29
MTU = 1420

[Peer]
PublicKey = <服务端公钥>
Endpoint = <服务端IP>:51820
AllowedIPs = 10.66.0.0/16, 192.168.0.0/16, 172.16.0.0/12
PersistentKeepalive = 25
```

## 📋 Windows客户端配置步骤

### 1. 导入配置文件

1. **打开WireGuard客户端**
2. **点击"添加隧道"**
3. **选择"从文件导入"**
4. **选择生成的.conf配置文件**

### 2. 扫描二维码导入

1. **在服务端生成配置时会显示二维码**
2. **在WireGuard客户端点击"添加隧道"**
3. **选择"从二维码创建"**
4. **扫描服务端显示的二维码**

### 3. 手动创建配置

1. **点击"添加空隧道"**
2. **输入隧道名称**
3. **复制粘贴配置内容**
4. **保存配置**

## 🔍 Windows客户端优化设置

### 1. 客户端软件设置

- **以管理员身份运行** - 确保有足够权限修改网络设置
- **开机自启动** - 在设置中启用"Launch on boot"
- **自动连接** - 启用"Auto-connect"选项

### 2. Windows系统优化

#### 防火墙设置
```powershell
# 允许WireGuard通过防火墙
New-NetFirewallRule -DisplayName "WireGuard" -Direction Inbound -Protocol UDP -Action Allow
New-NetFirewallRule -DisplayName "WireGuard" -Direction Outbound -Protocol UDP -Action Allow
```

#### 网络适配器优化
1. **打开"网络和共享中心"**
2. **点击"更改适配器设置"**
3. **右键WireGuard适配器 → 属性**
4. **取消勾选"Internet协议版本6 (TCP/IPv6)"**（如果不需要IPv6）
5. **点击"Internet协议版本4 (TCP/IPv4)" → 属性**
6. **设置DNS为"自动获取"**

### 3. 性能优化

#### 网络设置
- **使用有线网络连接**（比WiFi更稳定）
- **关闭Windows更新自动下载**（避免占用带宽）
- **禁用不必要的网络服务**

#### 系统设置
- **确保系统时间同步**
- **更新网卡驱动程序**
- **关闭不必要的后台程序**

## 🚨 故障排查

### 常见问题及解决方案

#### 1. 无法连接到服务端
**检查项目**：
- [ ] 服务端WireGuard服务是否运行
- [ ] 防火墙端口是否开放
- [ ] 客户端配置是否正确
- [ ] 网络连通性是否正常

**解决方法**：
```bash
# 在服务端检查服务状态
sudo systemctl status wg-quick@wg0

# 检查端口监听
sudo ss -ulpn | grep 51820

# 检查防火墙规则
sudo iptables -L | grep 51820
```

#### 2. 连接成功但无法访问网络
**可能原因**：
- DNS设置问题
- 路由配置问题
- MTU设置过大

**解决方法**：
- 尝试修改MTU值（1420 → 1280 → 1200）
- 检查DNS设置
- 重启网络适配器

#### 3. 连接不稳定，经常断开
**优化方法**：
- 调整PersistentKeepalive值（25 → 15）
- 检查网络质量
- 更新客户端软件

#### 4. 速度较慢
**优化建议**：
- 使用内网访问模式（partial）
- 选择地理位置更近的服务端
- 优化服务端网络配置

## 📊 连接测试

### 1. 基本连通性测试
```cmd
# 测试VPN连接
ping 10.66.0.1

# 测试DNS解析
nslookup google.com

# 测试外网连接
ping 8.8.8.8
```

### 2. IP地址检查
访问以下网站检查IP地址：
- https://whatismyipaddress.com/
- https://www.whatismyip.com/
- https://ipinfo.io/

### 3. 速度测试
- https://speedtest.net/
- https://fast.com/

## 🔐 安全建议

1. **定期更新客户端软件**
2. **不要共享配置文件**
3. **使用强密码保护设备**
4. **定期更换客户端密钥**
5. **监控异常连接**

## 📞 技术支持

如果遇到问题：
1. **查看客户端日志**
2. **检查服务端状态**
3. **运行网络诊断**
4. **提交GitHub Issue**

---

**总结**：通过服务端优化和正确的客户端配置，你可以获得稳定、高效的WireGuard VPN连接体验。
