# WireGuard 一体化安装脚本

## 🎉 全新单文件版本

这是一个**完全集成的单文件WireGuard安装脚本**，无需下载多个文件，一个脚本包含所有功能！

## 🚀 快速开始

### 下载并运行

```bash
# 下载脚本
wget https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh

# 设置执行权限
chmod +x wireguard-all-in-one.sh

# 运行脚本
sudo ./wireguard-all-in-one.sh
```

### 一键命令

```bash
wget https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh && chmod +x wireguard-all-in-one.sh && sudo ./wireguard-all-in-one.sh
```

## ✨ 功能特性

### 🌐 智能网络适配
- **自动检测网络环境**：智能判断国内/海外网络
- **镜像源优化**：国内环境自动使用阿里云镜像
- **DNS优化**：根据网络环境选择最优DNS
- **网络连通性测试**：安装前全面检测网络状态

### 🔧 系统优化
- **内核参数优化**：BBR拥塞控制、TCP优化
- **防火墙自动配置**：支持UFW、firewalld、iptables
- **系统服务管理**：自动配置systemd服务
- **IP转发配置**：自动启用IPv4/IPv6转发

### 🛡️ 安全特性
- **智能私网段选择**：避免与VPS内网冲突
- **强密钥生成**：使用WireGuard原生密钥生成
- **配置文件权限**：严格的文件权限控制
- **防火墙安全规则**：最小权限原则

### 📱 客户端管理
- **交互式添加客户端**：简单易用的客户端添加流程
- **二维码生成**：自动生成客户端配置二维码
- **客户端列表**：查看所有客户端状态
- **客户端删除**：安全删除不需要的客户端

### 🔍 监控诊断
- **服务状态监控**：实时显示WireGuard服务状态
- **网络诊断**：全面的网络连通性检测
- **故障排查**：自动检测常见问题
- **系统信息显示**：详细的系统和网络信息

## 📋 支持的系统

- ✅ Ubuntu 18.04+
- ✅ Debian 9+
- ✅ CentOS 7+
- ✅ RHEL 7+
- ✅ Fedora 30+

## 🎯 使用流程

### 1. 安装服务端
```bash
sudo ./wireguard-all-in-one.sh
# 选择 "1. 安装WireGuard服务端"
```

### 2. 添加客户端
```bash
# 在主菜单选择 "2. 添加客户端"
# 输入客户端名称
# 自动生成配置和二维码
```

### 3. 查看状态
```bash
# 选择 "5. 显示服务状态" 查看运行状态
# 选择 "4. 列出所有客户端" 查看客户端列表
```

## 🔧 命令行选项

```bash
# 显示帮助
./wireguard-all-in-one.sh --help

# 显示版本
./wireguard-all-in-one.sh --version

# 启用调试模式
./wireguard-all-in-one.sh --debug
```

## 🌟 主要优势

### 相比多文件版本的优势：

1. **单文件部署** - 只需下载一个文件
2. **无依赖问题** - 不需要担心文件缺失
3. **网络问题解决** - 优化了网络检测逻辑
4. **更好的错误处理** - 改进了错误处理机制
5. **调试模式** - 支持调试模式排查问题

### 针对国内网络的优化：

1. **智能网络检测** - 多种方式判断网络环境
2. **镜像源自动配置** - 国内环境使用阿里云镜像
3. **DNS优化** - 使用阿里DNS和腾讯DNS
4. **BBR优化** - 启用BBR拥塞控制算法
5. **网络参数调优** - 针对国内网络的参数优化

## 🔍 故障排查

### 如果脚本运行出错：

1. **启用调试模式**：
```bash
DEBUG_MODE=true sudo ./wireguard-all-in-one.sh
```

2. **检查系统日志**：
```bash
journalctl -u wg-quick@wg0 -f
```

3. **运行网络诊断**：
```bash
# 在主菜单选择 "6. 网络诊断"
```

### 常见问题：

1. **网络检测失败** - 脚本会继续运行，不会退出
2. **端口被占用** - 脚本会提示选择其他端口
3. **权限问题** - 确保使用sudo运行
4. **系统不支持** - 检查是否为支持的Linux发行版

## 📊 配置信息

### 默认配置：
- **端口**: 51820 (可自定义)
- **私网段**: 10.66.0.0/16 (可选择其他)
- **DNS**: 根据网络环境自动选择
- **配置目录**: /etc/wireguard/

### 文件位置：
- **服务端配置**: /etc/wireguard/wg0.conf
- **客户端配置**: /etc/wireguard/clients/
- **备份文件**: /root/wireguard-backup-*.tar.gz

## 🔄 更新脚本

```bash
# 下载最新版本
wget -O wireguard-all-in-one.sh https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-all-in-one.sh
chmod +x wireguard-all-in-one.sh
```

## 📞 技术支持

- **GitHub仓库**: https://github.com/senma231/WG-install
- **问题反馈**: 提交GitHub Issue
- **使用文档**: 查看仓库中的详细文档

## ⚖️ 许可证

本项目采用MIT许可证，请遵守当地法律法规使用。

---

## 🎯 总结

这个一体化脚本解决了原版本的所有问题：
- ✅ 单文件部署，无需多个脚本
- ✅ 优化了网络检测，不会因网络问题退出
- ✅ 更好的错误处理和用户提示
- ✅ 完整的功能集成
- ✅ 支持调试模式
- ✅ 针对国内网络环境优化

**推荐使用这个一体化版本！**
