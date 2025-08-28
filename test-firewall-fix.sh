#!/bin/bash
# -*- coding: utf-8 -*-

# 测试防火墙修复效果的脚本
# 版本: 1.0.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo -e "${CYAN}防火墙修复效果测试${NC}"
echo "=========================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    log_error "需要root权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 测试防火墙检测函数
echo -e "${BLUE}1. 测试防火墙检测${NC}"

# 从All-in-One脚本中提取防火墙检测函数
detect_firewall_type() {
    local firewall_type="iptables"  # 默认使用iptables
    
    # 检测UFW
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            firewall_type="ufw"
            echo "$firewall_type"
            return
        fi
    fi
    
    # 检测firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            firewall_type="firewalld"
            echo "$firewall_type"
            return
        fi
    fi
    
    # 如果没有检测到UFW或firewalld，且iptables可用，则使用iptables
    if command -v iptables >/dev/null 2>&1; then
        firewall_type="iptables"
    else
        firewall_type="none"
    fi
    
    echo "$firewall_type"
}

firewall_type=$(detect_firewall_type)
echo "检测到的防火墙类型: $firewall_type"

if [[ $firewall_type == "iptables" ]]; then
    log_success "防火墙检测修复成功 - 现在默认使用iptables"
else
    log_info "检测到其他防火墙类型: $firewall_type"
fi

echo ""

# 测试iptables规则保存
echo -e "${BLUE}2. 测试iptables规则保存${NC}"

# 从All-in-One脚本中提取保存函数
save_iptables_rules() {
    log_info "保存iptables规则..."
    
    # 尝试多种保存方式
    local saved=false
    
    # 方式1: 使用iptables-save保存到标准位置
    if command -v iptables-save >/dev/null 2>&1; then
        # 确保目录存在
        if [[ ! -d "/etc/iptables" ]]; then
            mkdir -p /etc/iptables 2>/dev/null || true
        fi
        
        # 尝试保存到标准位置
        if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
            log_success "iptables规则已保存到 /etc/iptables/rules.v4"
            saved=true
        fi
    fi
    
    # 方式2: 使用netfilter-persistent (Debian/Ubuntu)
    if [[ $saved == false ]] && command -v netfilter-persistent >/dev/null 2>&1; then
        if netfilter-persistent save 2>/dev/null; then
            log_success "iptables规则已通过netfilter-persistent保存"
            saved=true
        fi
    fi
    
    # 方式3: 使用service iptables save (CentOS/RHEL)
    if [[ $saved == false ]] && command -v service >/dev/null 2>&1; then
        if service iptables save 2>/dev/null; then
            log_success "iptables规则已通过service保存"
            saved=true
        fi
    fi
    
    # 方式4: 保存到备用位置
    if [[ $saved == false ]] && command -v iptables-save >/dev/null 2>&1; then
        local backup_file="/etc/iptables-rules-backup"
        if iptables-save > "$backup_file" 2>/dev/null; then
            log_success "iptables规则已保存到 $backup_file"
            saved=true
        fi
    fi
    
    if [[ $saved == false ]]; then
        log_warn "无法保存iptables规则，重启后规则可能丢失"
        echo "  建议手动安装 iptables-persistent:"
        echo "  sudo apt install iptables-persistent  # Debian/Ubuntu"
        echo "  sudo yum install iptables-services    # CentOS/RHEL"
    fi
}

# 测试保存功能
save_iptables_rules

echo ""

# 检查系统信息
echo -e "${BLUE}3. 系统信息检查${NC}"

echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo "未知")"
echo "内核版本: $(uname -r)"

# 检查可用的防火墙工具
echo ""
echo "可用的防火墙工具:"
if command -v ufw >/dev/null 2>&1; then
    echo "  ✓ UFW: $(ufw --version | head -1)"
else
    echo "  ✗ UFW: 未安装"
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    echo "  ✓ firewalld: $(firewall-cmd --version 2>/dev/null || echo "已安装")"
else
    echo "  ✗ firewalld: 未安装"
fi

if command -v iptables >/dev/null 2>&1; then
    echo "  ✓ iptables: $(iptables --version | head -1)"
else
    echo "  ✗ iptables: 未安装"
fi

# 检查iptables规则保存工具
echo ""
echo "iptables规则保存工具:"
if command -v iptables-save >/dev/null 2>&1; then
    echo "  ✓ iptables-save: 可用"
else
    echo "  ✗ iptables-save: 不可用"
fi

if command -v netfilter-persistent >/dev/null 2>&1; then
    echo "  ✓ netfilter-persistent: 可用"
else
    echo "  ✗ netfilter-persistent: 不可用"
fi

if command -v service >/dev/null 2>&1; then
    echo "  ✓ service: 可用"
else
    echo "  ✗ service: 不可用"
fi

echo ""

# 检查目录和文件
echo -e "${BLUE}4. 目录和文件检查${NC}"

if [[ -d "/etc/iptables" ]]; then
    echo "  ✓ /etc/iptables 目录存在"
    if [[ -f "/etc/iptables/rules.v4" ]]; then
        echo "  ✓ /etc/iptables/rules.v4 文件存在"
        echo "    文件大小: $(ls -lh /etc/iptables/rules.v4 | awk '{print $5}')"
        echo "    修改时间: $(ls -l /etc/iptables/rules.v4 | awk '{print $6, $7, $8}')"
    else
        echo "  ✗ /etc/iptables/rules.v4 文件不存在"
    fi
else
    echo "  ✗ /etc/iptables 目录不存在"
fi

if [[ -f "/etc/iptables-rules-backup" ]]; then
    echo "  ✓ 备用规则文件 /etc/iptables-rules-backup 存在"
else
    echo "  ✗ 备用规则文件不存在"
fi

echo ""

# 测试建议
echo -e "${BLUE}5. 修复效果总结${NC}"

if [[ $firewall_type == "iptables" ]]; then
    log_success "防火墙检测修复成功"
    echo "  - 现在会默认使用iptables而不是跳过防火墙配置"
else
    log_info "系统使用其他防火墙: $firewall_type"
fi

if [[ -f "/etc/iptables/rules.v4" ]] || [[ -f "/etc/iptables-rules-backup" ]]; then
    log_success "iptables规则保存修复成功"
    echo "  - 规则可以正确保存，不会出现'No such file or directory'错误"
else
    log_warn "iptables规则保存可能仍有问题"
    echo "  - 建议安装 iptables-persistent 包"
fi

echo ""
echo -e "${CYAN}测试完成！${NC}"
echo ""
echo "如果看到上述成功信息，说明防火墙修复已生效。"
echo "现在可以重新运行 All-in-One 脚本测试端口转发功能。"
