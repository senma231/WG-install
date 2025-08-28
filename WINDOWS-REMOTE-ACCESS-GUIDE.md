# Windows客户端远程访问指南

## 🎯 通过服务端公网IP远程访问Windows客户端

当Windows客户端连接到WireGuard VPN后，你可以通过服务端的公网IP来远程访问Windows客户端的各种服务。

## 🔧 工作原理

```
互联网用户 → 服务端公网IP:端口 → WireGuard隧道 → Windows客户端:服务端口
```

**端口转发流程**：
1. 用户访问服务端公网IP的指定端口
2. 服务端通过iptables规则将流量转发到WireGuard客户端
3. Windows客户端接收并处理请求
4. 响应数据原路返回

## 🚀 快速开始

### 1. 使用端口转发管理器

```bash
# 下载端口转发管理脚本
wget https://raw.githubusercontent.com/senma231/WG-install/main/port-forward-manager.sh
chmod +x port-forward-manager.sh

# 运行管理器
sudo ./port-forward-manager.sh
```

### 2. 或使用All-in-One脚本

```bash
# 运行一体化脚本
sudo ./wireguard-all-in-one.sh

# 选择 "6. 端口转发管理"
```

## 📱 常用远程访问场景

### 1. 远程桌面 (RDP)

**配置步骤**：
1. 运行端口转发管理器
2. 选择 "1. 添加端口转发规则"
3. 选择Windows客户端
4. 选择 "1. RDP (远程桌面) - 3389"
5. 设置公网端口（建议使用非标准端口如13389）

**Windows客户端设置**：
```powershell
# 启用远程桌面
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0

# 启用网络级别身份验证
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -value 1

# 允许防火墙
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

**连接方式**：
- Windows: `mstsc` → 输入 `服务端IP:13389`
- macOS: Microsoft Remote Desktop → 添加PC → `服务端IP:13389`
- Linux: `rdesktop 服务端IP:13389`

### 2. SSH访问 (如果Windows启用了OpenSSH)

**Windows启用OpenSSH**：
```powershell
# 安装OpenSSH服务器
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# 启动并设置自动启动
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# 防火墙规则
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

**端口转发配置**：
- 公网端口：2222 (避免与服务端SSH冲突)
- 目标端口：22
- 连接：`ssh username@服务端IP -p 2222`

### 3. Web服务访问

**场景**：Windows上运行的Web应用、开发服务器等

**配置示例**：
- 目标端口：8080 (Windows上的Web服务)
- 公网端口：8080
- 访问：`http://服务端IP:8080`

### 4. 文件传输服务

**FTP服务**：
- 目标端口：21
- 公网端口：2121
- 访问：`ftp://服务端IP:2121`

**HTTP文件服务器**：
- 目标端口：8000
- 公网端口：8000
- 访问：`http://服务端IP:8000`

## 🛡️ 安全配置建议

### 1. 端口安全

**使用非标准端口**：
```bash
# 不要使用标准端口
❌ RDP: 3389 → 使用 13389
❌ SSH: 22   → 使用 2222
❌ HTTP: 80  → 使用 8080
```

**端口范围建议**：
- 高端口：10000-65535
- 避免常用端口：21, 22, 23, 25, 53, 80, 110, 443, 993, 995

### 2. Windows防火墙配置

**允许特定端口**：
```powershell
# 允许RDP
New-NetFirewallRule -DisplayName "Allow RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow

# 允许自定义端口
New-NetFirewallRule -DisplayName "Allow Custom Port" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
```

**限制访问源**：
```powershell
# 仅允许VPN网段访问
New-NetFirewallRule -DisplayName "Allow VPN RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -RemoteAddress 10.66.0.0/16 -Action Allow
```

### 3. 用户账户安全

**创建专用远程用户**：
```powershell
# 创建远程访问用户
New-LocalUser -Name "remoteuser" -Password (ConvertTo-SecureString "StrongPassword123!" -AsPlainText -Force) -Description "Remote access user"

# 添加到远程桌面用户组
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "remoteuser"
```

**禁用不必要的用户**：
```powershell
# 禁用Guest账户
Disable-LocalUser -Name "Guest"
```

### 4. 访问日志监控

**启用登录审计**：
```powershell
# 启用登录事件审计
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
```

**查看登录日志**：
```powershell
# 查看远程登录事件
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} | Where-Object {$_.Message -like "*Network*"} | Select-Object TimeCreated, Id, LevelDisplayName, Message
```

## 🔍 故障排查

### 1. 连接问题诊断

**检查端口转发规则**：
```bash
# 在服务端检查iptables规则
sudo iptables -t nat -L PREROUTING -n | grep DNAT

# 检查端口监听
sudo ss -tulpn | grep :端口号
```

**测试网络连通性**：
```bash
# 从服务端测试客户端端口
telnet 客户端IP 目标端口

# 从外部测试公网端口
telnet 服务端IP 公网端口
```

### 2. Windows客户端检查

**检查服务状态**：
```powershell
# 检查RDP服务
Get-Service TermService

# 检查SSH服务
Get-Service sshd

# 检查防火墙状态
Get-NetFirewallProfile
```

**检查端口监听**：
```powershell
# 查看监听端口
netstat -an | findstr :3389
netstat -an | findstr :22
```

### 3. 常见问题解决

**问题1：无法连接到远程桌面**
```powershell
# 解决方案
# 1. 启用远程桌面
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0

# 2. 重启远程桌面服务
Restart-Service TermService -Force

# 3. 检查用户权限
net localgroup "Remote Desktop Users"
```

**问题2：连接被拒绝**
- 检查Windows防火墙设置
- 验证用户账户和密码
- 确认服务正在运行
- 检查网络级别身份验证设置

**问题3：连接超时**
- 检查端口转发规则是否正确
- 验证客户端是否在线
- 测试VPN连接状态

## 📊 性能优化

### 1. RDP性能优化

**注册表优化**：
```powershell
# 禁用桌面背景
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value ""

# 禁用视觉效果
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
```

**连接设置优化**：
- 降低颜色深度（16位）
- 禁用音频重定向
- 关闭打印机重定向
- 使用压缩

### 2. 网络优化

**MTU设置**：
```powershell
# 设置网络接口MTU
netsh interface ipv4 set subinterface "WireGuard Tunnel" mtu=1420 store=persistent
```

**TCP优化**：
```powershell
# 启用TCP窗口缩放
netsh int tcp set global autotuninglevel=normal

# 启用TCP Chimney
netsh int tcp set global chimney=enabled
```

## 📋 端口转发规则管理

### 查看当前规则
```bash
# 使用管理脚本查看
sudo ./port-forward-manager.sh
# 选择 "2. 列出端口转发规则"

# 手动查看iptables规则
sudo iptables -t nat -L PREROUTING -n --line-numbers
```

### 删除规则
```bash
# 使用管理脚本删除
sudo ./port-forward-manager.sh
# 选择 "3. 删除端口转发规则"

# 手动删除iptables规则
sudo iptables -t nat -D PREROUTING 规则编号
```

### 规则持久化
```bash
# 保存iptables规则
sudo iptables-save > /etc/iptables/rules.v4

# 或使用iptables-persistent
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

## 🎯 最佳实践

### 1. 安全最佳实践
- ✅ 使用强密码和密钥认证
- ✅ 定期更换访问凭据
- ✅ 监控访问日志
- ✅ 使用非标准端口
- ✅ 限制访问时间和IP范围

### 2. 性能最佳实践
- ✅ 选择合适的端口转发规则
- ✅ 优化网络参数
- ✅ 定期清理无用规则
- ✅ 监控网络流量

### 3. 管理最佳实践
- ✅ 记录所有端口转发规则
- ✅ 定期备份配置
- ✅ 测试故障恢复流程
- ✅ 保持脚本和系统更新

---

## 🎉 总结

通过WireGuard的端口转发功能，你可以安全、便捷地远程访问Windows客户端的各种服务。记住始终遵循安全最佳实践，定期监控和维护你的配置。

**快速开始命令**：
```bash
# 下载并运行端口转发管理器
wget https://raw.githubusercontent.com/senma231/WG-install/main/port-forward-manager.sh && chmod +x port-forward-manager.sh && sudo ./port-forward-manager.sh
```
