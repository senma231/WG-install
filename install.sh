#!/bin/bash
# -*- coding: utf-8 -*-

# WireGuard一键安装部署脚本
# 整合所有功能模块，提供完整的安装和配置体验
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
║              WireGuard 一键安装部署工具                       ║
║                                                              ║
║  🚀 功能特性:                                                 ║
║  • 完全交互式安装界面                                          ║
║  • 国内外网络环境自动适配                                      ║
║  • 智能网络优化配置                                            ║
║  • 批量客户端管理                                              ║
║  • 系统监控和故障诊断                                          ║
║  • 配置备份和恢复                                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${WHITE}版本: 1.0.0${NC}"
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

# 下载脚本文件
download_script() {
    local script_name=$1
    local script_url="https://raw.githubusercontent.com/senma231/WG-install/main/$script_name"

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

# 安装脚本到系统
install_scripts() {
    log_info "安装WireGuard工具集到系统..."

    # 创建安装目录
    mkdir -p "$INSTALL_DIR"

    # 脚本列表
    local scripts=(
        "wireguard-installer.sh"
        "china-network-optimizer.sh"
        "client-config-generator.sh"
        "wireguard-diagnostics.sh"
    )

    # 首先尝试从本地复制
    local local_install=true
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            cp "$SCRIPT_DIR/$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
            log_info "本地安装: $script"
        else
            local_install=false
            break
        fi
    done

    # 如果本地文件不完整，尝试在线下载
    if [[ $local_install == false ]]; then
        log_info "本地文件不完整，尝试在线下载..."

        # 检查网络连接
        if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            log_error "网络连接失败，无法下载脚本文件"
            log_error "请确保所有脚本文件都在同一目录下"
            exit 1
        fi

        # 下载脚本文件
        for script in "${scripts[@]}"; do
            if ! download_script "$script"; then
                log_error "下载 $script 失败"
                log_error "请手动下载所有脚本文件到同一目录"
                exit 1
            fi
            log_info "在线下载: $script"
        done
    fi

    # 创建符号链接到系统PATH
    ln -sf "$INSTALL_DIR/wireguard-installer.sh" /usr/local/bin/wg-install
    ln -sf "$INSTALL_DIR/china-network-optimizer.sh" /usr/local/bin/wg-optimize
    ln -sf "$INSTALL_DIR/client-config-generator.sh" /usr/local/bin/wg-client
    ln -sf "$INSTALL_DIR/wireguard-diagnostics.sh" /usr/local/bin/wg-diag

    log_info "系统命令创建完成:"
    echo "  wg-install  - WireGuard主安装程序"
    echo "  wg-optimize - 网络优化工具"
    echo "  wg-client   - 客户端配置管理"
    echo "  wg-diag     - 系统诊断工具"
}

# 显示主菜单
show_main_menu() {
    echo -e "${WHITE}请选择安装选项：${NC}"
    echo ""
    echo "1. 完整安装 (推荐)"
    echo "   - 安装WireGuard服务端"
    echo "   - 应用网络优化"
    echo "   - 安装所有管理工具"
    echo ""
    echo "2. 仅安装WireGuard服务端"
    echo "   - 基础WireGuard安装"
    echo "   - 不包含额外优化"
    echo ""
    echo "3. 仅安装管理工具"
    echo "   - 客户端配置管理器"
    echo "   - 系统诊断工具"
    echo "   - 网络优化工具"
    echo ""
    echo "4. 网络优化 (适用于已安装的系统)"
    echo "   - 针对国内网络环境优化"
    echo "   - 系统参数调优"
    echo ""
    echo "5. 系统诊断"
    echo "   - 检查WireGuard状态"
    echo "   - 网络连通性测试"
    echo "   - 性能分析"
    echo ""
    echo "0. 退出"
    echo ""
}

# 完整安装
full_install() {
    log_info "开始完整安装..."
    
    # 安装脚本到系统
    install_scripts
    
    echo ""
    log_info "启动WireGuard主安装程序..."
    sleep 2
    
    # 运行主安装脚本
    "$INSTALL_DIR/wireguard-installer.sh"
    
    echo ""
    read -p "WireGuard安装完成，是否立即应用网络优化？(Y/n): " apply_optimization
    if [[ ! $apply_optimization =~ ^[Nn]$ ]]; then
        log_info "应用网络优化..."
        "$INSTALL_DIR/china-network-optimizer.sh"
    fi
    
    echo ""
    log_info "完整安装完成！"
    echo ""
    echo "可用命令："
    echo "  wg-install  - WireGuard管理界面"
    echo "  wg-client   - 客户端配置管理"
    echo "  wg-diag     - 系统诊断"
    echo "  wg-optimize - 网络优化"
}

# 仅安装服务端
server_only_install() {
    log_info "仅安装WireGuard服务端..."
    
    install_scripts
    
    echo ""
    log_info "启动WireGuard服务端安装..."
    sleep 2
    
    "$INSTALL_DIR/wireguard-installer.sh"
}

# 仅安装管理工具
tools_only_install() {
    log_info "仅安装管理工具..."
    
    install_scripts
    
    log_info "管理工具安装完成！"
    echo ""
    echo "可用命令："
    echo "  wg-client   - 客户端配置管理"
    echo "  wg-diag     - 系统诊断"
    echo "  wg-optimize - 网络优化"
}

# 网络优化
network_optimization() {
    log_info "应用网络优化..."
    
    if [[ -f "$SCRIPT_DIR/china-network-optimizer.sh" ]]; then
        "$SCRIPT_DIR/china-network-optimizer.sh"
    else
        log_error "网络优化脚本不存在"
    fi
}

# 系统诊断
system_diagnosis() {
    log_info "启动系统诊断..."
    
    if [[ -f "$SCRIPT_DIR/wireguard-diagnostics.sh" ]]; then
        "$SCRIPT_DIR/wireguard-diagnostics.sh"
    else
        log_error "诊断脚本不存在"
    fi
}

# 显示使用帮助
show_help() {
    echo "WireGuard一键安装部署工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --version  显示版本信息"
    echo "  --full         执行完整安装"
    echo "  --server       仅安装服务端"
    echo "  --tools        仅安装管理工具"
    echo "  --optimize     应用网络优化"
    echo "  --diagnose     运行系统诊断"
    echo ""
    echo "交互模式:"
    echo "  直接运行脚本进入交互式安装界面"
    echo ""
    echo "示例:"
    echo "  $0              # 交互式安装"
    echo "  $0 --full       # 完整安装"
    echo "  $0 --diagnose   # 系统诊断"
}

# 主函数
main() {
    # 处理命令行参数
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "WireGuard安装工具 v1.0.0"
            exit 0
            ;;
        --full)
            check_root
            full_install
            exit 0
            ;;
        --server)
            check_root
            server_only_install
            exit 0
            ;;
        --tools)
            check_root
            tools_only_install
            exit 0
            ;;
        --optimize)
            check_root
            network_optimization
            exit 0
            ;;
        --diagnose)
            check_root
            system_diagnosis
            exit 0
            ;;
        "")
            # 交互模式
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 $0 --help 查看帮助"
            exit 1
            ;;
    esac
    
    # 交互模式
    check_root
    
    while true; do
        show_banner
        show_main_menu
        
        read -p "请选择安装选项 (0-5): " choice
        
        case $choice in
            1)
                full_install
                break
                ;;
            2)
                server_only_install
                break
                ;;
            3)
                tools_only_install
                break
                ;;
            4)
                network_optimization
                read -p "按回车键继续..."
                ;;
            5)
                system_diagnosis
                read -p "按回车键继续..."
                ;;
            0)
                log_info "感谢使用WireGuard安装工具！"
                exit 0
                ;;
            *)
                log_error "无效的选项，请重新选择"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
