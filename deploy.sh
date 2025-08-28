#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard 独立部署脚本
# 单文件包含所有必要功能，可独立运行
# 版本: 1.0.0

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

# 全局变量
SCRIPT_VERSION="1.0.0"
GITHUB_REPO="https://raw.githubusercontent.com/senma231/WG-install/main"
INSTALL_DIR="/opt/wireguard-tools"

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
║              WireGuard 独立部署工具                           ║
║                                                              ║
║  🚀 特性:                                                     ║
║  • 单文件独立运行                                              ║
║  • 自动下载完整脚本套件                                        ║
║  • 国内外网络环境自动适配                                      ║
║  • 完全交互式安装界面                                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}版本: ${SCRIPT_VERSION}${NC}"
    echo ""
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    local test_hosts=("8.8.8.8" "223.5.5.5")
    local network_ok=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            network_ok=true
            break
        fi
    done
    
    if [[ $network_ok == false ]]; then
        log_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    
    log_info "网络连接正常"
}

# 安装必要工具
install_tools() {
    log_info "安装必要工具..."
    
    # 检测系统类型
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        local system_type=$ID
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    
    case $system_type in
        ubuntu|debian)
            apt update
            apt install -y curl wget
            ;;
        centos|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y curl wget
            else
                yum install -y curl wget
            fi
            ;;
        *)
            log_warn "未知系统类型，跳过工具安装"
            ;;
    esac
}

# 下载脚本文件
download_script() {
    local script_name=$1
    local script_url="$GITHUB_REPO/$script_name"
    
    log_info "下载 $script_name..."
    
    # 尝试使用curl下载
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$script_url" -o "$INSTALL_DIR/$script_name"; then
            chmod +x "$INSTALL_DIR/$script_name"
            return 0
        fi
    fi
    
    # 尝试使用wget下载
    if command -v wget >/dev/null 2>&1; then
        if wget -q "$script_url" -O "$INSTALL_DIR/$script_name"; then
            chmod +x "$INSTALL_DIR/$script_name"
            return 0
        fi
    fi
    
    return 1
}

# 下载完整脚本套件
download_full_suite() {
    log_info "下载完整WireGuard脚本套件..."
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 脚本列表
    local scripts=(
        "wireguard-installer.sh"
        "china-network-optimizer.sh"
        "client-config-generator.sh"
        "wireguard-diagnostics.sh"
    )
    
    # 下载所有脚本
    local download_success=true
    for script in "${scripts[@]}"; do
        if ! download_script "$script"; then
            log_error "下载 $script 失败"
            download_success=false
        fi
    done
    
    if [[ $download_success == false ]]; then
        log_error "部分脚本下载失败，请检查网络连接"
        log_info "你也可以手动下载所有脚本文件到服务器"
        exit 1
    fi
    
    # 创建符号链接
    ln -sf "$INSTALL_DIR/wireguard-installer.sh" /usr/local/bin/wg-install
    ln -sf "$INSTALL_DIR/china-network-optimizer.sh" /usr/local/bin/wg-optimize
    ln -sf "$INSTALL_DIR/client-config-generator.sh" /usr/local/bin/wg-client
    ln -sf "$INSTALL_DIR/wireguard-diagnostics.sh" /usr/local/bin/wg-diag
    
    log_info "脚本套件下载完成！"
    echo ""
    echo "可用命令："
    echo "  wg-install  - WireGuard主安装程序"
    echo "  wg-optimize - 网络优化工具"
    echo "  wg-client   - 客户端配置管理"
    echo "  wg-diag     - 系统诊断工具"
}

# 显示使用说明
show_usage() {
    echo "WireGuard独立部署工具使用说明："
    echo ""
    echo "1. 下载脚本套件："
    echo "   选择此选项将下载完整的WireGuard脚本套件"
    echo "   包括主安装程序、优化工具、客户端管理器等"
    echo ""
    echo "2. 直接安装WireGuard："
    echo "   如果网络不稳定，可以选择内置的简化安装"
    echo "   提供基本的WireGuard安装功能"
    echo ""
    echo "3. 手动部署说明："
    echo "   如果自动下载失败，请手动下载以下文件："
    echo "   - wireguard-installer.sh"
    echo "   - china-network-optimizer.sh"
    echo "   - client-config-generator.sh"
    echo "   - wireguard-diagnostics.sh"
    echo "   然后运行 install.sh"
    echo ""
}

# 简化版WireGuard安装
simple_install() {
    log_info "开始简化版WireGuard安装..."
    
    # 这里可以包含一个简化的安装流程
    # 为了保持文件大小，这里只提供基本提示
    echo ""
    log_info "简化安装功能开发中..."
    log_info "建议使用完整脚本套件获得最佳体验"
    echo ""
    echo "手动安装步骤："
    echo "1. 安装WireGuard: apt install wireguard (Ubuntu/Debian)"
    echo "2. 生成密钥: wg genkey | tee privatekey | wg pubkey > publickey"
    echo "3. 配置服务端: 编辑 /etc/wireguard/wg0.conf"
    echo "4. 启动服务: systemctl enable --now wg-quick@wg0"
    echo ""
    echo "详细配置请参考官方文档或使用完整脚本套件"
}

# 主菜单
show_menu() {
    echo -e "${WHITE}请选择操作：${NC}"
    echo ""
    echo "1. 下载完整脚本套件 (推荐)"
    echo "2. 简化版WireGuard安装"
    echo "3. 显示使用说明"
    echo "0. 退出"
    echo ""
}

# 主函数
main() {
    check_root
    
    while true; do
        show_banner
        show_menu
        
        read -p "请选择操作 (0-3): " choice
        
        case $choice in
            1)
                check_network
                install_tools
                download_full_suite
                echo ""
                log_info "现在可以运行 wg-install 开始安装WireGuard"
                break
                ;;
            2)
                simple_install
                read -p "按回车键继续..."
                ;;
            3)
                show_usage
                read -p "按回车键继续..."
                ;;
            0)
                log_info "感谢使用WireGuard部署工具！"
                exit 0
                ;;
            *)
                log_error "无效的选项"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
