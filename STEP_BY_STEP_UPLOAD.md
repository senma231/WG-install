# GitHub上传详细步骤指南

## 🚀 方法一：使用自动上传脚本（推荐）

### 1. 准备工作
```bash
# 确保在包含所有脚本文件的目录中
ls -la *.sh *.md

# 给上传脚本执行权限
chmod +x git-upload.sh
```

### 2. 运行自动上传脚本
```bash
./git-upload.sh
```

脚本会自动：
- 检查Git是否安装
- 验证所有必需文件
- 设置Git配置（如果需要）
- 克隆仓库
- 复制文件
- 提交并推送到GitHub

## 🔧 方法二：手动Git命令（如果自动脚本失败）

### 1. 安装Git（如果未安装）
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install git

# CentOS/RHEL
sudo yum install git

# 或者
sudo dnf install git
```

### 2. 配置Git（首次使用）
```bash
git config --global user.name "你的用户名"
git config --global user.email "你的邮箱@example.com"
```

### 3. 克隆仓库
```bash
git clone https://github.com/senma231/WG-install.git
cd WG-install
```

### 4. 复制所有文件
```bash
# 假设你的脚本在上级目录
cp ../*.sh ./
cp ../*.md ./

# 或者指定具体路径
cp /path/to/your/scripts/* ./
```

### 5. 设置文件权限
```bash
chmod +x *.sh
```

### 6. 添加文件到Git
```bash
git add .
```

### 7. 检查要提交的文件
```bash
git status
```

### 8. 提交更改
```bash
git commit -m "feat: 添加完整的WireGuard安装脚本套件

✨ 功能特性:
- 完全交互式安装界面
- 国内外网络环境自动适配
- 智能网络优化配置
- 批量客户端管理功能
- 系统监控和故障诊断工具
- 配置备份和恢复功能

🔧 技术特性:
- 支持多种Linux发行版
- UTF-8编码支持
- 智能私网段选择
- 防火墙自动配置

📦 包含文件:
- deploy.sh: 单文件部署工具（推荐）
- install.sh: 完整安装工具
- wireguard-installer.sh: 核心安装程序
- china-network-optimizer.sh: 网络优化工具
- client-config-generator.sh: 客户端管理器
- wireguard-diagnostics.sh: 系统诊断工具
- 完整的文档和使用指南"
```

### 9. 推送到GitHub
```bash
git push origin main
```

## 🌐 方法三：使用GitHub Web界面

### 1. 访问仓库
打开浏览器访问：https://github.com/senma231/WG-install

### 2. 上传文件
1. 点击 "Add file" 按钮
2. 选择 "Upload files"
3. 拖拽以下文件到上传区域：
   - deploy.sh
   - install.sh
   - wireguard-installer.sh
   - china-network-optimizer.sh
   - client-config-generator.sh
   - wireguard-diagnostics.sh
   - README.md
   - USAGE_GUIDE.md
   - DEPLOYMENT.md
   - CHANGELOG.md

### 3. 填写提交信息
```
标题: feat: 添加完整的WireGuard安装脚本套件

描述:
✨ 新功能:
- 完全交互式安装界面
- 国内外网络环境自动适配
- 智能网络优化配置
- 批量客户端管理功能
- 系统监控和故障诊断工具

🚀 快速使用:
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh && chmod +x deploy.sh && sudo ./deploy.sh
```

### 4. 提交更改
点击 "Commit changes" 按钮

## 🔐 认证问题解决

### 如果推送时要求认证：

#### 方法A：使用Personal Access Token
1. 访问 GitHub Settings -> Developer settings -> Personal access tokens
2. 生成新的token，勾选 `repo` 权限
3. 使用token作为密码：
```bash
git push origin main
# 用户名: senma231
# 密码: 你的personal_access_token
```

#### 方法B：配置SSH密钥
1. 生成SSH密钥：
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

2. 添加到GitHub：
```bash
cat ~/.ssh/id_rsa.pub
# 复制输出内容到 GitHub Settings -> SSH and GPG keys
```

3. 使用SSH URL：
```bash
git remote set-url origin git@github.com:senma231/WG-install.git
git push origin main
```

## ✅ 上传完成后验证

### 1. 检查仓库页面
访问：https://github.com/senma231/WG-install

### 2. 测试文件下载
```bash
# 测试主要脚本
curl -I https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
curl -I https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-installer.sh

# 实际下载测试
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
```

### 3. 测试自动下载功能
```bash
# 在测试服务器上
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh
./deploy.sh
# 选择"下载完整脚本套件"，验证是否能正常下载其他脚本
```

## 🎯 推荐的上传顺序

1. **首先尝试自动脚本**：`./git-upload.sh`
2. **如果失败，使用手动Git命令**
3. **最后选择Web界面上传**

## 📞 常见问题解决

### 问题1：Permission denied (publickey)
**解决**：配置SSH密钥或使用HTTPS + Personal Access Token

### 问题2：fatal: not a git repository
**解决**：确保在正确的目录中，重新克隆仓库

### 问题3：Updates were rejected
**解决**：先拉取最新更改
```bash
git pull origin main
git push origin main
```

### 问题4：Large files detected
**解决**：检查是否有大文件，脚本文件应该都很小

## 🎉 上传成功后

上传成功后，用户就可以通过以下方式使用你的脚本：

```bash
# 单文件快速部署
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh

# 完整套件克隆
git clone https://github.com/senma231/WG-install.git
cd WG-install
chmod +x *.sh
sudo ./install.sh
```

---

**建议**：首先尝试运行 `./git-upload.sh`，这是最简单的方式。如果遇到问题，再按照手动步骤操作。
