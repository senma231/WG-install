#!/bin/bash
# -*- coding: utf-8 -*-

# GitHub上传脚本
# 自动上传WireGuard脚本套件到GitHub仓库

# 设置UTF-8编码环境
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 仓库信息
REPO_URL="https://github.com/senma231/WG-install.git"
REPO_NAME="WG-install"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                GitHub 自动上传工具                           ║
║                                                              ║
║  目标仓库: senma231/WG-install                               ║
║  包含文件: 完整WireGuard脚本套件                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

# 检查Git是否安装
check_git() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git未安装，请先安装Git"
        echo "Ubuntu/Debian: sudo apt install git"
        echo "CentOS/RHEL: sudo yum install git"
        exit 1
    fi
    log_info "Git已安装: $(git --version)"
}

# 检查文件完整性
check_files() {
    log_info "检查文件完整性..."
    
    local required_files=(
        "deploy.sh"
        "install.sh"
        "wireguard-installer.sh"
        "china-network-optimizer.sh"
        "client-config-generator.sh"
        "wireguard-diagnostics.sh"
        "README.md"
        "USAGE_GUIDE.md"
        "DEPLOYMENT.md"
        "CHANGELOG.md"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "缺少以下文件："
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    log_info "所有必需文件都存在"
}

# 设置Git配置
setup_git() {
    log_info "设置Git配置..."
    
    # 检查Git用户配置
    if ! git config user.name >/dev/null 2>&1; then
        read -p "请输入Git用户名: " git_username
        git config --global user.name "$git_username"
    fi
    
    if ! git config user.email >/dev/null 2>&1; then
        read -p "请输入Git邮箱: " git_email
        git config --global user.email "$git_email"
    fi
    
    log_info "Git配置完成"
    echo "用户名: $(git config user.name)"
    echo "邮箱: $(git config user.email)"
}

# 克隆或更新仓库
setup_repository() {
    log_info "设置仓库..."
    
    if [[ -d "$REPO_NAME" ]]; then
        log_info "仓库目录已存在，更新中..."
        cd "$REPO_NAME"
        git pull origin main || log_warn "拉取更新失败，继续执行..."
        cd ..
    else
        log_info "克隆仓库..."
        if ! git clone "$REPO_URL"; then
            log_error "克隆仓库失败，请检查："
            echo "1. 网络连接是否正常"
            echo "2. 仓库地址是否正确"
            echo "3. 是否有访问权限"
            exit 1
        fi
    fi
}

# 复制文件
copy_files() {
    log_info "复制文件到仓库目录..."
    
    local files_to_copy=(
        "deploy.sh"
        "install.sh"
        "wireguard-installer.sh"
        "china-network-optimizer.sh"
        "client-config-generator.sh"
        "wireguard-diagnostics.sh"
        "README.md"
        "USAGE_GUIDE.md"
        "DEPLOYMENT.md"
        "CHANGELOG.md"
        "upload-to-github.md"
    )
    
    for file in "${files_to_copy[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$REPO_NAME/"
            log_info "复制: $file"
        fi
    done
    
    # 设置脚本执行权限
    cd "$REPO_NAME"
    chmod +x *.sh
    cd ..
}

# 提交更改
commit_changes() {
    log_info "提交更改到Git..."
    
    cd "$REPO_NAME"
    
    # 添加所有文件
    git add .
    
    # 检查是否有更改
    if git diff --cached --quiet; then
        log_warn "没有检测到文件更改"
        cd ..
        return
    fi
    
    # 显示将要提交的更改
    echo ""
    log_info "将要提交的更改："
    git diff --cached --name-status
    echo ""
    
    # 确认提交
    read -p "确认提交这些更改？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消提交"
        cd ..
        return
    fi
    
    # 提交更改
    local commit_message="feat: 更新WireGuard完整安装脚本套件

✨ 新功能:
- 完全交互式安装界面
- 国内外网络环境自动适配
- 智能网络优化配置
- 批量客户端管理功能
- 系统监控和故障诊断工具
- 配置备份和恢复功能

🔧 技术特性:
- 支持Ubuntu/Debian/CentOS/RHEL/Fedora
- 自动检测网络环境并优化配置
- 智能私网段选择避免冲突
- 防火墙自动配置
- UTF-8编码支持，解决中文显示问题

📦 脚本文件:
- deploy.sh: 单文件部署工具（推荐）
- install.sh: 完整安装工具
- wireguard-installer.sh: 核心安装程序
- china-network-optimizer.sh: 网络优化工具
- client-config-generator.sh: 客户端管理器
- wireguard-diagnostics.sh: 系统诊断工具

🚀 使用方法:
wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh && chmod +x deploy.sh && sudo ./deploy.sh"
    
    git commit -m "$commit_message"
    
    cd ..
    log_info "提交完成"
}

# 推送到GitHub
push_to_github() {
    log_info "推送到GitHub..."
    
    cd "$REPO_NAME"
    
    # 推送到远程仓库
    if git push origin main; then
        log_info "推送成功！"
        echo ""
        echo "🎉 上传完成！"
        echo ""
        echo "仓库地址: $REPO_URL"
        echo "快速使用: wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh"
        echo ""
    else
        log_error "推送失败，可能的原因："
        echo "1. 网络连接问题"
        echo "2. 认证失败（需要配置SSH密钥或Personal Access Token）"
        echo "3. 权限不足"
        echo ""
        echo "请检查GitHub认证设置后重试"
    fi
    
    cd ..
}

# 显示使用说明
show_usage() {
    echo "GitHub上传工具使用说明："
    echo ""
    echo "此脚本将自动："
    echo "1. 检查所需文件是否完整"
    echo "2. 设置Git配置"
    echo "3. 克隆或更新GitHub仓库"
    echo "4. 复制脚本文件到仓库"
    echo "5. 提交更改并推送到GitHub"
    echo ""
    echo "使用前请确保："
    echo "- 已安装Git"
    echo "- 已配置GitHub认证（SSH密钥或Personal Access Token）"
    echo "- 有仓库的写入权限"
    echo ""
}

# 主函数
main() {
    show_banner
    
    # 显示使用说明
    show_usage
    read -p "按回车键继续，或Ctrl+C取消..."
    
    # 执行上传流程
    check_git
    check_files
    setup_git
    setup_repository
    copy_files
    commit_changes
    push_to_github
    
    echo ""
    log_info "上传流程完成！"
    echo ""
    echo "接下来你可以："
    echo "1. 访问 $REPO_URL 查看仓库"
    echo "2. 测试脚本下载: wget https://raw.githubusercontent.com/senma231/WG-install/main/deploy.sh"
    echo "3. 在服务器上测试安装功能"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
