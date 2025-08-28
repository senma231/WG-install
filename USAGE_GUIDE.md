# WireGuard 完整安装脚本使用指南

## 📋 脚本套件概览

本套件包含5个核心脚本，提供从安装到管理的完整WireGuard解决方案：

### 🚀 核心脚本

1. **`install.sh`** - 一键安装部署工具
2. **`wireguard-installer.sh`** - 主安装和管理程序
3. **`china-network-optimizer.sh`** - 国内网络优化工具
4. **`client-config-generator.sh`** - 客户端配置批量管理器
5. **`wireguard-diagnostics.sh`** - 系统诊断和故障排查工具

## 🎯 快速开始

### 方法一：一键安装（推荐）
```bash
# 下载脚本
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh

# 运行一键安装
sudo ./deploy.sh
```

### 方法二：完整套件安装
```bash
# 下载完整套件
git clone https://github.com/senma231/WG-install.git
cd WG-install
chmod +x *.sh

# 运行安装脚本
sudo ./install.sh
```

## 📖 详细使用说明

### 1. 一键安装工具 (`install.sh`)

这是整个套件的入口脚本，提供多种安装选项：

#### 交互式安装
```bash
sudo ./install.sh
```

#### 命令行安装
```bash
# 完整安装（推荐）
sudo ./install.sh --full

# 仅安装服务端
sudo ./install.sh --server

# 仅安装管理工具
sudo ./install.sh --tools

# 应用网络优化
sudo ./install.sh --optimize

# 运行系统诊断
sudo ./install.sh --diagnose
```

#### 安装后可用命令
安装完成后，以下命令将在系统中可用：
- `wg-install` - WireGuard管理界面
- `wg-client` - 客户端配置管理
- `wg-diag` - 系统诊断工具
- `wg-optimize` - 网络优化工具

### 2. 主安装程序 (`wireguard-installer.sh`)

提供完整的WireGuard服务端和客户端管理功能：

#### 主要功能
- ✅ 自动检测系统环境（Ubuntu/Debian/CentOS/RHEL/Fedora）
- ✅ 智能网络环境检测（国内/海外）
- ✅ 自动配置镜像源（国内环境使用阿里云镜像）
- ✅ 智能私网段选择（避免VPS内网冲突）
- ✅ 防火墙自动配置（UFW/firewalld/iptables）
- ✅ 客户端配置生成和二维码显示
- ✅ 配置备份和恢复
- ✅ 服务状态监控

#### 使用流程
1. 运行脚本：`sudo ./wireguard-installer.sh`
2. 选择"1. 安装WireGuard服务端"
3. 按提示配置端口和私网段
4. 等待自动安装和配置
5. 添加客户端配置

### 3. 网络优化工具 (`china-network-optimizer.sh`)

专门针对国内网络环境的深度优化：

#### 优化内容
- 🔧 启用BBR拥塞控制算法
- 🔧 优化TCP/UDP缓冲区大小
- 🔧 配置国内DNS服务器
- 🔧 调整系统网络参数
- 🔧 优化文件句柄限制
- 🔧 创建网络监控脚本

#### 使用方法
```bash
sudo ./china-network-optimizer.sh
```

**注意**：优化后建议重启系统以确保所有参数生效。

### 4. 客户端配置管理器 (`client-config-generator.sh`)

提供批量客户端配置生成和管理功能：

#### 主要功能
- 📱 批量生成客户端配置
- 📱 导出现有客户端配置
- 📱 生成客户端使用统计
- 📱 清理过期配置文件
- 📱 自动生成二维码

#### 使用示例
```bash
sudo ./client-config-generator.sh
```

选择功能：
1. **批量生成** - 一次性生成多个客户端配置
2. **导出配置** - 导出现有客户端配置和二维码
3. **使用统计** - 查看客户端连接状态和系统信息
4. **清理配置** - 删除过期的配置文件

### 5. 系统诊断工具 (`wireguard-diagnostics.sh`)

全面的系统检测和故障排查工具：

#### 检查项目
- 🔍 系统基础信息检查
- 🔍 WireGuard服务状态检查
- 🔍 网络接口状态检查
- 🔍 防火墙配置检查
- 🔍 网络连通性测试
- 🔍 系统参数检查
- 🔍 WireGuard连接状态
- 🔍 系统性能检查

#### 使用方法
```bash
sudo ./wireguard-diagnostics.sh
```

脚本会自动执行所有检查项目，并可选择生成详细的诊断报告。

## 🌐 网络环境适配

### 国内网络环境优化

脚本会自动检测网络环境，对于国内网络提供以下优化：

1. **镜像源优化**
   - Ubuntu: 使用阿里云镜像
   - Debian: 使用阿里云镜像
   - CentOS: 使用阿里云镜像

2. **DNS优化**
   - 阿里DNS: 223.5.5.5
   - 腾讯DNS: 119.29.29.29

3. **网络参数优化**
   - 启用BBR拥塞控制
   - 优化TCP/UDP缓冲区
   - 调整网络队列参数

### 海外网络环境

对于海外网络环境，脚本会：
- 使用官方软件源
- 配置Google DNS (8.8.8.8, 1.1.1.1)
- 应用标准网络优化参数

## 🔒 安全特性

### 私网段选择
脚本提供多个不常用的私网段选项，避免与VPS内网冲突：
- `10.66.0.0/16` (推荐)
- `10.88.0.0/16`
- `172.31.0.0/16`
- `192.168.233.0/24`
- `192.168.188.0/24`

### 密钥管理
- 使用WireGuard原生密钥生成
- 配置文件权限严格控制 (600)
- 自动生成强随机密钥

### 防火墙配置
- 自动检测防火墙类型
- 配置最小权限规则
- 支持UFW、firewalld、iptables

## 📁 文件结构

安装后的文件结构：
```
/etc/wireguard/
├── wg0.conf                 # 服务端配置文件
└── clients/                 # 客户端配置目录
    ├── client001.conf
    ├── client002.conf
    └── ...

/opt/wireguard-tools/        # 工具安装目录
├── wireguard-installer.sh
├── china-network-optimizer.sh
├── client-config-generator.sh
└── wireguard-diagnostics.sh

/root/wireguard-backup/      # 配置备份目录
├── wireguard-backup-20231201-120000.tar.gz
└── ...

/root/wireguard-exports/     # 配置导出目录
├── batch-20231201-120000/
└── export-20231201-120000/
```

## 🚨 故障排查

### 常见问题及解决方案

1. **服务启动失败**
   ```bash
   # 查看服务状态
   systemctl status wg-quick@wg0
   
   # 查看详细日志
   journalctl -u wg-quick@wg0 -f
   
   # 运行诊断工具
   wg-diag
   ```

2. **客户端无法连接**
   - 检查防火墙设置
   - 验证服务器公网IP
   - 确认端口是否开放
   - 运行网络诊断

3. **网络速度慢**
   - 运行网络优化工具
   - 检查BBR是否启用
   - 调整MTU设置

### 日志位置
- WireGuard服务日志: `journalctl -u wg-quick@wg0`
- 系统日志: `/var/log/syslog`
- 诊断日志: `/var/log/wireguard-diagnostics.log`

## 🔄 更新和维护

### 脚本更新
```bash
# 重新下载最新版本
wget -O deploy.sh https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### WireGuard更新
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade wireguard

# CentOS/RHEL
sudo yum update wireguard-tools
```

### 定期维护
- 定期备份配置: 使用主脚本的备份功能
- 监控系统状态: 运行诊断工具
- 清理过期文件: 使用客户端管理器的清理功能

## 📞 技术支持

如果遇到问题：
1. 首先运行诊断工具: `wg-diag`
2. 查看相关日志文件
3. 检查网络连通性
4. 参考故障排查部分

## ⚖️ 许可证和免责声明

- 本脚本套件采用MIT许可证
- 请确保遵守当地法律法规
- 合规使用VPN服务
- 作者不承担任何使用风险

---

**注意**: 使用前请仔细阅读所有说明，确保理解各项功能和风险。
