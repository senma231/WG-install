# WireGuard 脚本部署指南

## 📋 部署方式选择

根据你的需求和网络环境，有以下几种部署方式：

### 🚀 方式一：单文件部署（推荐）

**适用场景**：网络稳定，可以在线下载
**优点**：只需上传一个文件，自动下载完整套件

```bash
# 1. 上传 deploy.sh 到服务器
scp deploy.sh root@your-server:/root/

# 2. 登录服务器运行
ssh root@your-server
chmod +x deploy.sh
./deploy.sh
```

### 📦 方式二：完整套件部署

**适用场景**：网络不稳定或需要离线部署
**优点**：所有功能完整，无需网络下载

```bash
# 1. 上传所有脚本文件到服务器
scp *.sh root@your-server:/root/wireguard/

# 2. 登录服务器运行安装脚本
ssh root@your-server
cd /root/wireguard/
chmod +x *.sh
./install.sh
```

### ⚡ 方式三：直接运行主脚本

**适用场景**：只需要基本安装功能
**优点**：最简单直接

```bash
# 1. 上传主脚本
scp wireguard-installer.sh root@your-server:/root/

# 2. 运行主脚本
ssh root@your-server
chmod +x wireguard-installer.sh
./wireguard-installer.sh
```

## 🔧 编码问题解决方案

### 已解决的编码问题

所有脚本已经添加了UTF-8编码声明：
```bash
#!/bin/bash
# -*- coding: utf-8 -*-

# 设置UTF-8编码环境
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

### 如果仍然出现乱码

1. **检查终端编码**：
```bash
echo $LANG
echo $LC_ALL
```

2. **手动设置编码**：
```bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

3. **系统级编码设置**：
```bash
# Ubuntu/Debian
sudo locale-gen zh_CN.UTF-8
sudo update-locale LANG=zh_CN.UTF-8

# CentOS/RHEL
sudo localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8
```

## 📁 文件上传方式

### 使用SCP上传

```bash
# 上传单个文件
scp deploy.sh root@your-server:/root/

# 上传所有脚本文件
scp *.sh root@your-server:/root/wireguard/

# 上传并保持权限
scp -p *.sh root@your-server:/root/wireguard/
```

### 使用SFTP上传

```bash
sftp root@your-server
put deploy.sh
put *.sh
quit
```

### 使用rsync上传

```bash
rsync -avz *.sh root@your-server:/root/wireguard/
```

### 通过Web面板上传

如果你使用宝塔面板、cPanel等：
1. 登录Web管理面板
2. 进入文件管理
3. 上传脚本文件到 `/root/` 目录
4. 设置文件权限为 755

## 🎯 推荐部署流程

### 第一次部署（推荐）

1. **上传deploy.sh**：
```bash
scp deploy.sh root@your-server:/root/
```

2. **登录服务器**：
```bash
ssh root@your-server
```

3. **运行部署脚本**：
```bash
chmod +x deploy.sh
./deploy.sh
```

4. **选择"下载完整脚本套件"**

5. **运行主安装程序**：
```bash
wg-install
```

### 离线部署

如果服务器无法访问GitHub：

1. **本地下载所有文件**
2. **上传到服务器**：
```bash
scp *.sh *.md root@your-server:/root/wireguard/
```

3. **运行安装**：
```bash
ssh root@your-server
cd /root/wireguard/
chmod +x *.sh
./install.sh
```

## 🔍 部署验证

### 检查文件完整性

```bash
# 检查所有脚本文件
ls -la *.sh

# 检查文件权限
ls -la *.sh | grep rwx

# 检查编码
file *.sh
```

### 测试脚本运行

```bash
# 测试主脚本
./wireguard-installer.sh --help

# 测试部署脚本
./deploy.sh --help
```

### 验证编码正确

```bash
# 运行脚本查看中文显示
./deploy.sh
# 应该能正确显示中文界面
```

## ⚠️ 常见问题解决

### 1. 权限问题

```bash
# 问题：Permission denied
# 解决：
chmod +x *.sh
```

### 2. 编码问题

```bash
# 问题：中文显示乱码
# 解决：
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

### 3. 网络问题

```bash
# 问题：无法下载脚本
# 解决：使用完整套件部署方式
```

### 4. 系统兼容性

```bash
# 问题：系统不支持
# 解决：检查系统版本
cat /etc/os-release
```

## 📊 部署后验证

### 检查安装结果

```bash
# 检查系统命令
which wg-install
which wg-client
which wg-diag
which wg-optimize

# 检查安装目录
ls -la /opt/wireguard-tools/

# 运行诊断
wg-diag
```

### 功能测试

```bash
# 测试主程序
wg-install

# 测试客户端管理
wg-client

# 测试系统诊断
wg-diag

# 测试网络优化
wg-optimize
```

## 🔄 更新和维护

### 更新脚本

```bash
# 重新下载最新版本
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

### 备份配置

```bash
# 备份WireGuard配置
tar -czf wireguard-backup.tar.gz /etc/wireguard/
```

## 📞 技术支持

如果遇到部署问题：

1. **检查系统日志**：`journalctl -f`
2. **运行诊断工具**：`wg-diag`
3. **查看脚本日志**：检查错误输出
4. **网络连通性**：`ping 8.8.8.8`

---

**总结**：
- **简单部署**：只上传 `deploy.sh`
- **完整部署**：上传所有 `.sh` 文件
- **编码问题**：已经解决，脚本包含UTF-8设置
- **推荐方式**：使用 `deploy.sh` 进行自动部署
