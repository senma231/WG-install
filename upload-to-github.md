# 上传到GitHub仓库指南

## 📋 准备工作

### 1. 确认仓库信息
- **仓库地址**: https://github.com/senma231/WG-install.git
- **主分支**: main
- **所有脚本已更新**: GitHub链接已更新为正确的仓库地址

### 2. 文件清单
以下文件需要上传到GitHub仓库：

```
WG-install/
├── deploy.sh                    # 🔥 主要入口脚本（推荐使用）
├── install.sh                   # 完整安装工具
├── wireguard-installer.sh       # 核心安装程序
├── china-network-optimizer.sh   # 网络优化工具
├── client-config-generator.sh   # 客户端管理器
├── wireguard-diagnostics.sh     # 系统诊断工具
├── README.md                    # 项目说明文档
├── USAGE_GUIDE.md              # 详细使用指南
├── DEPLOYMENT.md               # 部署指南
├── CHANGELOG.md                # 更新日志
└── upload-to-github.md         # 本文件（可选）
```

## 🚀 上传步骤

### 方法一：使用Git命令行（推荐）

```bash
# 1. 克隆仓库（如果是新仓库）
git clone https://github.com/senma231/WG-install.git
cd WG-install

# 2. 复制所有脚本文件到仓库目录
cp /path/to/your/scripts/* ./

# 3. 添加所有文件
git add .

# 4. 提交更改
git commit -m "feat: 添加完整的WireGuard安装脚本套件

- 支持国内外网络环境自动适配
- 完全交互式安装界面
- 智能网络优化配置
- 批量客户端管理功能
- 系统监控和故障诊断工具
- 配置备份和恢复功能"

# 5. 推送到GitHub
git push origin main
```

### 方法二：使用GitHub Web界面

1. 访问 https://github.com/senma231/WG-install
2. 点击 "Add file" -> "Upload files"
3. 拖拽所有脚本文件到上传区域
4. 填写提交信息
5. 点击 "Commit changes"

## 📝 更新的内容

### 已更新的GitHub链接

所有脚本中的下载链接已更新为：
```
https://raw.githubusercontent.com/senma231/WG-install/main/
```

### 主要更新文件

1. **deploy.sh**: 
   - 更新 `GITHUB_REPO` 变量
   - 指向正确的仓库地址

2. **install.sh**:
   - 更新下载链接
   - 修正脚本URL路径

3. **README.md**:
   - 更新快速开始部分的下载链接
   - 修正脚本更新命令

4. **USAGE_GUIDE.md**:
   - 更新安装方法中的链接
   - 添加Git克隆方式

5. **DEPLOYMENT.md**:
   - 更新脚本更新部分的链接

## 🎯 推荐的使用方式

上传完成后，用户可以通过以下方式使用：

### 单文件快速部署（推荐）
```bash
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### 完整套件克隆
```bash
git clone https://github.com/senma231/WG-install.git
cd WG-install
chmod +x *.sh
sudo ./install.sh
```

### 直接下载主脚本
```bash
wget https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-installer.sh
chmod +x wireguard-installer.sh
sudo ./wireguard-installer.sh
```

## 📋 上传后验证

### 1. 检查文件可访问性
```bash
# 测试主要脚本是否可下载
curl -I https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
curl -I https://raw.githubusercontent.com/senma231/WG-install/main/wireguard-installer.sh
```

### 2. 测试自动下载功能
```bash
# 在测试服务器上验证
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh
chmod +x deploy.sh
./deploy.sh  # 选择下载完整脚本套件，验证是否能正常下载
```

## 🔧 仓库设置建议

### 1. 设置仓库描述
```
WireGuard完整安装脚本套件 - 支持国内外网络环境，完全交互式操作，智能网络优化
```

### 2. 添加标签（Tags）
- `wireguard`
- `vpn`
- `linux`
- `china-network`
- `automation`
- `bash-script`

### 3. 设置README徽章（可选）
```markdown
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-green.svg)
![Shell](https://img.shields.io/badge/shell-bash-yellow.svg)
```

## 📊 使用统计

上传后可以通过以下方式查看使用情况：
- GitHub Insights -> Traffic
- 监控Raw文件的访问量
- 查看仓库的Star和Fork数量

## 🔄 后续维护

### 版本更新流程
1. 修改本地脚本文件
2. 更新版本号（在脚本头部）
3. 更新CHANGELOG.md
4. 提交并推送到GitHub
5. 创建Release标签（可选）

### 问题反馈处理
- 启用GitHub Issues
- 设置Issue模板
- 及时回复用户问题
- 收集使用反馈进行改进

---

**注意**: 上传完成后，请测试所有下载链接确保正常工作，特别是`deploy.sh`的自动下载功能。
