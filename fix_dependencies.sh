#!/bin/bash

# 依赖修复脚本
# 专门用于解决Ubuntu 22.04上的包依赖冲突问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        log_info "使用方法: sudo $0"
        exit 1
    fi
}

# 备份APT配置
backup_apt_config() {
    log_info "备份APT配置..."
    
    local backup_dir="/tmp/apt_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份重要的APT文件
    cp -r /etc/apt/sources.list* "$backup_dir/" 2>/dev/null || true
    cp -r /etc/apt/trusted.gpg* "$backup_dir/" 2>/dev/null || true
    cp -r /var/lib/apt/lists "$backup_dir/" 2>/dev/null || true
    
    log_success "APT配置已备份到: $backup_dir"
    echo "$backup_dir" > /tmp/apt_backup_location
}

# 清理APT缓存和锁定文件
clean_apt_cache() {
    log_info "清理APT缓存和锁定文件..."
    
    # 停止可能正在运行的APT进程
    killall apt apt-get dpkg 2>/dev/null || true
    
    # 删除锁定文件
    rm -f /var/lib/dpkg/lock-frontend
    rm -f /var/lib/dpkg/lock
    rm -f /var/cache/apt/archives/lock
    
    # 清理APT缓存
    apt clean
    apt autoclean
    
    log_success "APT缓存清理完成"
}

# 修复损坏的包
fix_broken_packages() {
    log_info "修复损坏的包..."
    
    # 配置未完成的包
    dpkg --configure -a
    
    # 修复损坏的依赖
    apt --fix-broken install -y
    
    # 强制安装缺失的依赖
    apt install -f -y
    
    log_success "损坏包修复完成"
}

# 更新包数据库
update_package_database() {
    log_info "更新包数据库..."
    
    # 更新包列表
    apt update --fix-missing
    
    # 升级包数据库
    apt list --upgradable > /dev/null 2>&1 || true
    
    log_success "包数据库更新完成"
}

# 解决libpcap依赖冲突
fix_libpcap_conflict() {
    log_info "解决libpcap依赖冲突..."
    
    # 检查当前libpcap状态
    local libpcap_status=$(dpkg -l | grep libpcap || true)
    if [ -n "$libpcap_status" ]; then
        log_info "当前libpcap包状态:"
        echo "$libpcap_status"
    fi
    
    # 尝试不同的解决方案
    log_info "尝试解决方案1: 重新安装libpcap包..."
    if apt reinstall -y libpcap0.8 2>/dev/null; then
        log_success "libpcap0.8重新安装成功"
    else
        log_warning "libpcap0.8重新安装失败"
    fi
    
    log_info "尝试解决方案2: 安装libpcap-dev..."
    if apt install -y libpcap-dev 2>/dev/null; then
        log_success "libpcap-dev安装成功"
    else
        log_warning "libpcap-dev安装失败，尝试替代方案..."
        
        # 尝试手动解决版本冲突
        log_info "尝试解决方案3: 手动解决版本冲突..."
        apt remove -y libpcap0.8-dev 2>/dev/null || true
        apt autoremove -y
        apt install -y libpcap-dev 2>/dev/null || true
    fi
}

# 安装编译依赖
install_build_dependencies() {
    log_info "安装编译依赖..."
    
    # 基础编译工具
    local basic_tools=(
        "build-essential"
        "make"
        "gcc"
        "g++"
        "pkg-config"
    )
    
    # 开发库
    local dev_libs=(
        "libssl-dev"
        "zlib1g-dev"
        "libcurl4-openssl-dev"
    )
    
    # 安装基础工具
    log_info "安装基础编译工具..."
    for tool in "${basic_tools[@]}"; do
        if apt install -y "$tool"; then
            log_success "$tool 安装成功"
        else
            log_error "$tool 安装失败"
        fi
    done
    
    # 安装开发库
    log_info "安装开发库..."
    for lib in "${dev_libs[@]}"; do
        if apt install -y "$lib"; then
            log_success "$lib 安装成功"
        else
            log_error "$lib 安装失败"
        fi
    done
    
    # 特殊处理libpcap
    fix_libpcap_conflict
}

# 验证依赖安装
verify_dependencies() {
    log_info "验证依赖安装..."
    
    local deps=(
        "gcc:gcc --version"
        "make:make --version"
        "pkg-config:pkg-config --version"
    )
    
    local success_count=0
    
    for dep_info in "${deps[@]}"; do
        IFS=':' read -r dep_name dep_cmd <<< "$dep_info"
        
        if command -v "$dep_name" >/dev/null 2>&1; then
            if $dep_cmd >/dev/null 2>&1; then
                log_success "$dep_name 可用"
                ((success_count++))
            else
                log_warning "$dep_name 已安装但可能有问题"
            fi
        else
            log_error "$dep_name 未找到"
        fi
    done
    
    # 检查libpcap
    if pkg-config --exists libpcap 2>/dev/null; then
        log_success "libpcap 开发库可用"
        ((success_count++))
    else
        log_warning "libpcap 开发库不可用 (hcxtools可能无法编译)"
    fi
    
    log_info "依赖验证完成: $success_count 个主要依赖可用"
}

# 清理系统
cleanup_system() {
    log_info "清理系统..."
    
    # 自动移除不需要的包
    apt autoremove -y
    
    # 清理包缓存
    apt autoclean
    
    # 清理孤立的包
    deborphan 2>/dev/null | xargs apt remove -y 2>/dev/null || true
    
    log_success "系统清理完成"
}

# 显示修复结果
show_results() {
    echo
    echo "=================================="
    echo "    依赖修复完成"
    echo "=================================="
    echo
    echo "修复操作已完成，现在可以尝试运行hashcat安装脚本："
    echo "  sudo ./install_hashcat_offline.sh"
    echo
    echo "如果仍有问题，请检查："
    echo "  1. 网络连接是否正常"
    echo "  2. 磁盘空间是否充足"
    echo "  3. 系统是否为Ubuntu 22.04"
    echo
    echo "备份位置："
    if [ -f /tmp/apt_backup_location ]; then
        echo "  $(cat /tmp/apt_backup_location)"
    fi
    echo
}

# 主函数
main() {
    echo "=================================="
    echo "  APT依赖修复脚本"
    echo "  适用于 Ubuntu 22.04"
    echo "=================================="
    echo
    
    # 检查权限
    check_root
    
    # 备份配置
    backup_apt_config
    
    # 清理APT
    clean_apt_cache
    
    # 修复损坏的包
    fix_broken_packages
    
    # 更新包数据库
    update_package_database
    
    # 安装编译依赖
    install_build_dependencies
    
    # 验证依赖
    verify_dependencies
    
    # 清理系统
    cleanup_system
    
    # 显示结果
    show_results
    
    log_success "依赖修复脚本执行完成！"
}

# 错误处理
trap 'log_error "依赖修复过程中发生错误"' ERR

# 执行主函数
main "$@"
