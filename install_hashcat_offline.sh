#!/bin/bash

# Hashcat 离线安装脚本 for Ubuntu 22.04
# 版本: 1.0
# 功能: 在完全离线的Ubuntu 22.04服务器上安装和编译hashcat-6.2.6、hashcat-utils-1.9和hcxtools-6.3.0
# 作者: AI Assistant
# 日期: 2024

set -e  # 遇到错误立即退出

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

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local desc="$3"
    local percent=$((current * 100 / total))
    local bar_length=40
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r${BLUE}[PROGRESS]${NC} ["
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "] %3d%% %s" "$percent" "$desc"
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        log_info "使用方法: sudo $0"
        exit 1
    fi
}

# 检查Ubuntu版本
check_ubuntu_version() {
    log_info "检查Ubuntu版本..."
    
    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    source /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        log_error "此脚本仅支持Ubuntu系统"
        exit 1
    fi
    
    if [ "$VERSION_ID" != "22.04" ]; then
        log_warning "此脚本专为Ubuntu 22.04设计，当前版本: $VERSION_ID"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
    
    log_success "Ubuntu版本检查通过: $VERSION_ID"
}

# 检查必需的源码包
check_source_packages() {
    log_info "检查源码包..."
    
    local packages=(
        "hashcat-6.2.6.tar.gz"
        "hashcat-utils-1.9.tar.gz"
        "hcxtools-6.3.0.tar.gz"
    )
    
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if [ ! -f "$package" ]; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        log_error "缺少以下源码包:"
        for package in "${missing_packages[@]}"; do
            echo "  - $package"
        done
        log_info "请确保所有源码包都在当前目录中"
        exit 1
    fi
    
    log_success "所有源码包检查完成"
}

# 修复APT依赖问题
fix_apt_dependencies() {
    log_info "检查并修复APT依赖问题..."

    # 清理APT缓存
    apt clean

    # 修复损坏的依赖
    apt --fix-broken install -y

    # 更新包数据库
    apt update --fix-missing

    # 尝试自动解决依赖冲突
    apt autoremove -y

    log_success "APT依赖问题修复完成"
}

# 安装编译依赖
install_build_dependencies() {
    log_info "安装编译依赖..."

    # 检查是否有网络连接
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_info "检测到网络连接，使用在线安装"

        # 先修复可能的依赖问题
        fix_apt_dependencies
        
        # 安装编译工具和依赖
        log_info "安装编译工具..."

        # 先尝试修复可能的依赖问题
        log_info "修复依赖问题..."
        apt --fix-broken install -y || true

        # 分步安装依赖，避免冲突
        log_info "安装基础编译工具..."
        apt install -y \
            build-essential \
            make \
            gcc \
            g++ \
            pkg-config

        log_info "安装开发库..."
        apt install -y \
            libssl-dev \
            zlib1g-dev \
            libcurl4-openssl-dev

        # 特殊处理libpcap，尝试不同的包名
        log_info "安装libpcap开发库..."
        if ! apt install -y libpcap-dev; then
            log_warning "libpcap-dev安装失败，尝试libpcap0.8-dev..."
            if ! apt install -y libpcap0.8-dev; then
                log_warning "libpcap开发库安装失败，hcxtools可能无法编译"
                log_info "您可以稍后手动安装: sudo apt install libpcap-dev"
            fi
        fi
            
    else
        log_warning "未检测到网络连接，假设依赖已安装"
        log_info "如果编译失败，请确保已安装以下包:"
        echo "  - build-essential"
        echo "  - make"
        echo "  - gcc"
        echo "  - g++"
        echo "  - pkg-config"
        echo "  - libssl-dev"
        echo "  - zlib1g-dev"
        echo "  - libcurl4-openssl-dev"
        echo "  - libpcap-dev"
        
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
    
    log_success "依赖安装完成"
}

# 创建安装目录
create_install_dirs() {
    log_info "创建安装目录..."
    
    local dirs=(
        "/opt/hashcat"
        "/opt/hashcat-utils"
        "/opt/hcxtools"
        "/usr/local/bin"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_info "创建目录: $dir"
    done
    
    log_success "安装目录创建完成"
}

# 编译和安装hashcat
install_hashcat() {
    log_info "开始编译和安装hashcat-6.2.6..."
    
    # 解压源码
    if [ ! -d "hashcat-6.2.6" ]; then
        log_info "解压hashcat-6.2.6.tar.gz..."
        tar -xzf hashcat-6.2.6.tar.gz
    fi
    
    cd hashcat-6.2.6
    
    # 清理之前的编译
    log_info "清理之前的编译文件..."
    make clean 2>/dev/null || true
    
    # 编译
    log_info "编译hashcat (这可能需要几分钟)..."
    show_progress 1 4 "编译中..."
    
    if ! make -j$(nproc); then
        log_error "hashcat编译失败"
        cd ..
        exit 1
    fi
    
    show_progress 2 4 "编译完成"
    
    # 安装到/opt/hashcat
    log_info "安装hashcat到/opt/hashcat..."
    cp -r . /opt/hashcat/
    
    show_progress 3 4 "文件复制完成"
    
    # 创建符号链接
    log_info "创建符号链接..."
    ln -sf /opt/hashcat/hashcat /usr/local/bin/hashcat
    
    show_progress 4 4 "hashcat安装完成"
    
    cd ..
    log_success "hashcat-6.2.6 安装完成"
}

# 编译和安装hashcat-utils
install_hashcat_utils() {
    log_info "开始编译和安装hashcat-utils-1.9..."

    # 解压源码
    if [ ! -d "hashcat-utils-1.9" ]; then
        log_info "解压hashcat-utils-1.9.tar.gz..."
        tar -xzf hashcat-utils-1.9.tar.gz
    fi

    cd hashcat-utils-1.9

    # 检查目录结构
    if [ ! -d "src" ] || [ ! -f "src/Makefile" ]; then
        log_error "hashcat-utils源码结构不正确"
        cd ..
        return 1
    fi

    # 进入src目录进行编译
    cd src

    # 清理之前的编译
    log_info "清理之前的编译文件..."
    make clean 2>/dev/null || true

    # 编译
    log_info "编译hashcat-utils..."
    show_progress 1 4 "编译中..."

    # 使用native目标编译
    if ! make native -j$(nproc); then
        log_warning "hashcat-utils编译失败，尝试单线程编译..."
        if ! make native; then
            log_error "hashcat-utils编译失败"
            cd ../..
            return 1
        fi
    fi
    
    show_progress 2 4 "编译完成"

    # 移动编译好的二进制文件到bin目录
    log_info "整理编译文件..."
    cd ..  # 回到hashcat-utils-1.9根目录

    # 确保bin目录存在
    mkdir -p bin

    # 移动编译好的文件
    if [ -d "src" ]; then
        # 移动二进制文件
        find src -name "*.bin" -exec mv {} bin/ \; 2>/dev/null || true
        # 移动Perl脚本
        find src -name "*.pl" -exec cp {} bin/ \; 2>/dev/null || true
    fi

    show_progress 3 4 "文件整理完成"

    # 安装到/opt/hashcat-utils
    log_info "安装hashcat-utils到/opt/hashcat-utils..."
    cp -r . /opt/hashcat-utils/

    # 创建符号链接
    log_info "创建符号链接..."
    if [ -d "bin" ] && [ "$(ls -A bin 2>/dev/null)" ]; then
        for tool in bin/*; do
            if [ -f "$tool" ] && [ -x "$tool" ]; then
                tool_name=$(basename "$tool")
                ln -sf "/opt/hashcat-utils/$tool" "/usr/local/bin/$tool_name"
                log_info "创建链接: $tool_name"
            fi
        done
        show_progress 4 4 "hashcat-utils安装完成"
    else
        log_warning "未找到编译好的工具，但源码已安装"
        show_progress 4 4 "hashcat-utils源码安装完成"
    fi

    cd ..
    log_success "hashcat-utils-1.9 安装完成"
}

# 编译和安装hcxtools
install_hcxtools() {
    log_info "开始编译和安装hcxtools-6.3.0..."

    # 检查libpcap是否可用
    local has_libpcap=false
    if pkg-config --exists libpcap 2>/dev/null; then
        has_libpcap=true
        log_success "检测到libpcap支持"
    else
        log_warning "未检测到libpcap，部分hcxtools功能可能不可用"
    fi

    # 解压源码
    if [ ! -d "hcxtools-6.3.0" ]; then
        log_info "解压hcxtools-6.3.0.tar.gz..."
        tar -xzf hcxtools-6.3.0.tar.gz
    fi

    cd hcxtools-6.3.0

    # 清理之前的编译
    log_info "清理之前的编译文件..."
    make clean 2>/dev/null || true

    # 编译
    log_info "编译hcxtools..."
    show_progress 1 4 "编译中..."

    # 尝试编译，如果失败则尝试不同的编译选项
    if ! make -j$(nproc) 2>/dev/null; then
        log_warning "标准编译失败，尝试无libpcap编译..."
        if ! make -j$(nproc) CFLAGS="-O3 -Wall -Wextra -std=gnu99" 2>/dev/null; then
            log_error "hcxtools编译失败，跳过此组件"
            cd ..
            return 1
        fi
    fi
    
    show_progress 2 4 "编译完成"
    
    # 安装
    log_info "安装hcxtools..."
    if ! make install PREFIX=/opt/hcxtools; then
        log_error "hcxtools安装失败"
        cd ..
        exit 1
    fi
    
    show_progress 3 4 "安装完成"
    
    # 创建符号链接
    log_info "创建符号链接..."
    if [ -d "/opt/hcxtools/bin" ]; then
        for tool in /opt/hcxtools/bin/*; do
            if [ -f "$tool" ] && [ -x "$tool" ]; then
                tool_name=$(basename "$tool")
                ln -sf "$tool" "/usr/local/bin/$tool_name"
            fi
        done
    fi
    
    show_progress 4 4 "hcxtools安装完成"
    
    cd ..
    log_success "hcxtools-6.3.0 安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    local tools=(
        "hashcat:hashcat --version"
        "hcxpcapngtool:hcxpcapngtool --version"
    )
    
    local success_count=0
    local total_count=${#tools[@]}
    
    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool_name tool_cmd <<< "$tool_info"
        
        log_info "测试 $tool_name..."
        
        if command -v "$tool_name" >/dev/null 2>&1; then
            if $tool_cmd >/dev/null 2>&1; then
                log_success "$tool_name 工作正常"
                ((success_count++))
            else
                log_warning "$tool_name 已安装但可能有问题"
            fi
        else
            log_error "$tool_name 未找到"
        fi
    done
    
    log_info "验证完成: $success_count/$total_count 工具正常工作"
    
    if [ $success_count -eq $total_count ]; then
        log_success "所有工具安装验证成功！"
        return 0
    else
        log_warning "部分工具可能存在问题"
        return 1
    fi
}

# 显示安装信息
show_installation_info() {
    echo
    echo "=================================="
    echo "    Hashcat 离线安装完成"
    echo "=================================="
    echo
    echo "安装位置:"
    echo "  - hashcat:       /opt/hashcat/"
    echo "  - hashcat-utils: /opt/hashcat-utils/"
    echo "  - hcxtools:      /opt/hcxtools/"
    echo
    echo "可执行文件链接:"
    echo "  - /usr/local/bin/hashcat"
    echo "  - /usr/local/bin/hcxpcapngtool"
    echo "  - 其他工具链接在 /usr/local/bin/"
    echo
    echo "使用方法:"
    echo "  hashcat --help"
    echo "  hcxpcapngtool --help"
    echo
    echo "注意事项:"
    echo "  - 确保 /usr/local/bin 在您的 PATH 中"
    echo "  - 某些功能可能需要 OpenCL 驱动支持"
    echo "  - 建议重新登录以刷新环境变量"
    echo
}

# 主函数
main() {
    echo "=================================="
    echo "  Hashcat 离线安装脚本 v1.0"
    echo "  适用于 Ubuntu 22.04"
    echo "=================================="
    echo
    
    # 检查权限
    check_root
    
    # 检查系统版本
    check_ubuntu_version
    
    # 检查源码包
    check_source_packages
    
    # 安装依赖
    install_build_dependencies
    
    # 创建安装目录
    create_install_dirs
    
    # 安装各个组件
    local install_results=()

    log_info "开始安装hashcat..."
    if install_hashcat; then
        install_results+=("hashcat:SUCCESS")
    else
        install_results+=("hashcat:FAILED")
        log_error "hashcat安装失败"
    fi

    log_info "开始安装hashcat-utils..."
    if install_hashcat_utils; then
        install_results+=("hashcat-utils:SUCCESS")
    else
        install_results+=("hashcat-utils:FAILED")
        log_error "hashcat-utils安装失败"
    fi

    log_info "开始安装hcxtools..."
    if install_hcxtools; then
        install_results+=("hcxtools:SUCCESS")
    else
        install_results+=("hcxtools:FAILED")
        log_warning "hcxtools安装失败，但不影响hashcat使用"
    fi

    # 显示安装结果
    echo
    log_info "安装结果汇总:"
    for result in "${install_results[@]}"; do
        IFS=':' read -r component status <<< "$result"
        if [ "$status" = "SUCCESS" ]; then
            log_success "$component 安装成功"
        else
            log_error "$component 安装失败"
        fi
    done
    
    # 验证安装
    verify_installation
    
    # 显示安装信息
    show_installation_info
    
    log_success "安装脚本执行完成！"
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    log_error "脚本执行过程中发生错误 (退出码: $exit_code)"
    echo
    echo "=================================="
    echo "    错误处理建议"
    echo "=================================="
    echo
    echo "1. 运行依赖修复脚本:"
    echo "   sudo ./fix_dependencies.sh"
    echo
    echo "2. 查看详细故障排除指南:"
    echo "   cat TROUBLESHOOTING.md"
    echo
    echo "3. 检查系统环境:"
    echo "   ./test_install_check.sh"
    echo
    echo "4. 手动安装依赖:"
    echo "   sudo apt install build-essential libssl-dev"
    echo
    exit $exit_code
}

# 错误处理
trap 'handle_error' ERR

# 执行主函数
main "$@"
