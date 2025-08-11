#!/bin/bash
# 字典处理工具 v2.0
# 功能增强的字典清理、去重、合并工具
# 专为WiFi密码破解优化

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 版本信息
VERSION="2.1"
SCRIPT_NAME="字典处理工具 - 多核优化版"

# 显示使用说明
show_usage() {
    echo -e "${CYAN}$SCRIPT_NAME v$VERSION${NC}"
    echo -e "${YELLOW}用法:${NC}"
    echo -e "  $0 clean <输入文件> [输出文件] [选项]     - 清理单个字典文件"
    echo -e "  $0 merge <输出文件> <文件1> <文件2> [文件3...] - 合并多个字典文件"
    echo -e "  $0 dedup <输入文件> [输出文件] [选项]     - 仅去重处理"
    echo -e "  $0 analyze <文件>                       - 分析字典文件统计信息"
    echo
    echo -e "${YELLOW}通用性能选项:${NC}"
    echo -e "  --memory-ratio=N  内存使用比例（默认：0.6，即60%）"
    echo -e "  --jobs=N          并行CPU核心数（默认：自动检测）"
    echo -e "  --temp-dir=PATH   临时文件目录（默认：/tmp）"
    echo -e "  --debug           启用调试模式，显示详细信息"
    echo
    echo -e "${YELLOW}清理功能专用选项:${NC}"
    echo -e "  --keep-utf8       保留UTF-8字符（默认：移除）"
    echo -e "  --min-len=N       最小长度过滤（默认：8位）"
    echo -e "  --max-len=N       最大长度过滤（默认：63位）"
    echo -e "  --no-examples     不显示密码示例（加快处理速度）"
    echo
    echo -e "${YELLOW}性能优化功能:${NC}"
    echo -e "  ⚡ 多核并行处理 - 大文件自动启用多线程加速"
    echo -e "  🧠 智能内存管理 - 根据可用内存自动选择处理策略"
    echo -e "  📦 分块处理 - 超大文件分块处理，避免内存溢出"
    echo -e "  🔄 智能去重 - 内存充足时快速去重，不足时分块去重"
    echo
    echo -e "${YELLOW}各功能说明:${NC}"
    echo -e "  📝 clean  - 仅清理：移除非法字符、长度过滤（不去重）[支持性能参数]"
    echo -e "  🔗 merge  - 仅合并：多文件合并（不去重、不清理）"
    echo -e "  🔄 dedup  - 仅去重：智能去重处理（不清理、不过滤）[支持性能参数]"
    echo -e "  📊 analyze- 仅分析：统计信息和建议（不修改文件）"
    echo
    echo -e "${YELLOW}清理功能详情:${NC}"
    echo -e "  ✓ 移除非法字符（控制字符、不可见字符）"
    echo -e "  ✓ 移除非ASCII字符（可选保留UTF-8）"
    echo -e "  ✓ 移除二进制数据"
    echo -e "  ✓ 过滤WiFi密码长度（8-63位）"
    echo -e "  ✓ 详细统计信息"
    echo
    echo -e "${YELLOW}基础示例:${NC}"
    echo -e "  # 1. 清理原始字典（移除非法字符、长度过滤）"
    echo -e "  $0 clean raw_dict.txt clean_dict.txt"
    echo -e ""
    echo -e "  # 2. 合并多个字典文件"
    echo -e "  $0 merge combined.txt dict1.txt dict2.txt dict3.txt"
    echo -e ""
    echo -e "  # 3. 去重处理（自动选择最优策略：小文件用AWK，大文件用sort）"
    echo -e "  $0 dedup combined.txt unique_dict.txt"
    echo -e ""
    echo -e "  # 4. 分析字典统计"
    echo -e "  $0 analyze unique_dict.txt"
    echo
    echo -e "${YELLOW}完整流程示例:${NC}"
    echo -e "  # 完整的字典处理流程（带性能优化）"
    echo -e "  $0 clean raw1.txt clean1.txt --jobs=8 --memory-ratio=0.6"
    echo -e "  $0 clean raw2.txt clean2.txt --jobs=8 --memory-ratio=0.6"
    echo -e "  $0 merge combined.txt clean1.txt clean2.txt"
    echo -e "  $0 dedup combined.txt final_dict.txt --jobs=6 --memory-ratio=0.5"
    echo -e "  $0 analyze final_dict.txt"
    echo
    echo -e "${YELLOW}性能优化示例:${NC}"
    echo -e "  # 小文件快速处理"
    echo -e "  $0 clean small.txt --jobs=1"
    echo -e "  $0 dedup small.txt --jobs=1"
    echo -e ""
    echo -e "  # 大文件多核加速（>50亿行自动启用并行sort去重）"
    echo -e "  $0 clean large.txt --jobs=8 --memory-ratio=0.6"
    echo -e "  $0 dedup large.txt --jobs=8 --memory-ratio=0.6"
    echo -e ""
    echo -e "  # 指定临时目录（推荐使用SSD或大容量磁盘）"
    echo -e "  $0 clean huge.txt --temp-dir=/data/tmp --jobs=8"
    echo -e "  $0 dedup huge.txt --temp-dir=/data/tmp --memory-ratio=0.6"
    echo -e ""
    echo -e "  # 内存受限环境"
    echo -e "  $0 clean huge.txt --jobs=4 --memory-ratio=0.3"
    echo -e "  $0 dedup huge.txt --jobs=4 --memory-ratio=0.3"
    echo -e ""
    echo -e "  # 高性能服务器"
    echo -e "  $0 clean massive.txt --jobs=16 --memory-ratio=0.8"
    echo -e "  $0 dedup massive.txt --jobs=12 --memory-ratio=0.7"
    echo -e ""
    echo -e "  # 保留中文密码（仅清理功能）"
    echo -e "  $0 clean chinese.txt --keep-utf8 --jobs=4"
    echo -e ""
    echo -e "  # 自定义长度范围（仅清理功能）"
    echo -e "  $0 clean custom.txt --min-len=6 --max-len=20 --jobs=8"
    echo
    echo -e "${CYAN}💡 性能提示:${NC}"
    echo -e "  • 文件 < 100万行：自动使用单线程（最优）"
    echo -e "  • 文件 ≥ 100万行：自动启用多线程并行处理"
    echo -e "  • 内存充足时：使用快速内存去重"
    echo -e "  • 内存不足时：自动切换分块处理策略"
    echo -e "  • 建议并行数：CPU核心数的50%-100%"
    echo -e "  • 建议内存比例：0.3-0.8之间"
    echo
    exit 1
}

# 全局变量
TEMP_DIR=""
TEMP_BASE_DIR="/home/aiserver/ai/data/code/crack/tmp"  # 临时文件基础目录
KEEP_UTF8=false
MIN_LENGTH=8
MAX_LENGTH=63
MEMORY_RATIO=0.6  # 默认使用60%可用内存
DEBUG_MODE=false  # 调试模式
SHOW_EXAMPLES=true  # 显示密码示例

# 内存监控函数
check_memory_usage() {
    local current_mem_usage=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [ "$current_mem_usage" -gt 90 ]; then
        echo -e "${RED}❌ 警告：内存使用率已达到${current_mem_usage}%，停止处理以防止系统崩溃${NC}"
        echo -e "${RED}建议：减少 --memory-ratio 参数或使用更小的 --jobs 参数${NC}"
        exit 1
    fi
}

# 时间格式化函数
format_time() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ "$hours" -gt 0 ]; then
        echo "${hours}小时${minutes}分${secs}秒"
    elif [ "$minutes" -gt 0 ]; then
        echo "${minutes}分${secs}秒"
    else
        echo "${secs}秒"
    fi
}

# 新增内存计算函数
calculate_memory_limit() {
    local ratio="$1"
    # 获取可用内存（KB）
    local available_mem_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    # 计算可用内存（MB）
    local available_mem_mb=$((available_mem_kb / 1024))
    # 计算允许使用的内存（MB）
    local allowed_mem_mb=$(echo "$available_mem_mb * $ratio" | bc -l | cut -d. -f1)

    echo "$allowed_mem_mb"
}

# 估算文件去重所需内存
estimate_dedup_memory() {
    local input_file="$1"
    local file_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")

    # 动态计算平均行长度（采样前10000行获得更准确的估计）
    local avg_line_length
    if [ "$file_lines" -gt 10000 ]; then
        avg_line_length=$(head -10000 "$input_file" | awk '{sum += length($0); count++} END {printf "%.0f", sum/count}')
    else
        avg_line_length=$(awk '{sum += length($0); count++} END {printf "%.0f", sum/count}' "$input_file")
    fi

    # 如果无法计算，使用保守估计
    if [ -z "$avg_line_length" ] || [ "$avg_line_length" -eq 0 ]; then
        avg_line_length=12  # 保守估计
    fi

    # 对于sort去重，内存需求主要是：
    # 1. 字符串存储：实际字符串长度 + 换行符
    # 2. sort内部开销：每行约32-64字节（指针、排序结构等）
    # 3. 系统缓冲区开销：额外20-30%

    # 基础内存需求（字节）
    local base_memory_per_line=$((avg_line_length + 1))  # +1 for newline
    local sort_overhead_per_line=48  # sort内部结构开销
    local total_per_line=$((base_memory_per_line + sort_overhead_per_line))

    # 计算基础内存需求（MB）
    local base_estimated_mb=$((file_lines * total_per_line / 1024 / 1024))

    # 系统缓冲区和碎片化开销（30%）
    local estimated_mb=$((base_estimated_mb * 130 / 100))

    # 根据文件规模调整安全系数（sort对超大文件内存使用更不可预测）
    if [ "$file_lines" -gt 10000000000 ]; then  # 超过100亿行
        estimated_mb=$((estimated_mb * 3))      # 增加200%安全系数
    elif [ "$file_lines" -gt 5000000000 ]; then # 超过50亿行
        estimated_mb=$((estimated_mb * 5 / 2))  # 增加150%安全系数
    elif [ "$file_lines" -gt 1000000000 ]; then # 超过10亿行
        estimated_mb=$((estimated_mb * 2))      # 增加100%安全系数
    elif [ "$file_lines" -gt 100000000 ]; then  # 超过1亿行
        estimated_mb=$((estimated_mb * 3 / 2))  # 增加50%安全系数
    fi

    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${PURPLE}🐛 内存估算详情:${NC}" >&2
        echo -e "${PURPLE}  - 文件行数: $(printf "%'d" $file_lines)${NC}" >&2
        echo -e "${PURPLE}  - 平均行长度: ${avg_line_length}字符${NC}" >&2
        echo -e "${PURPLE}  - 哈希开销: ${hash_overhead}字节/行${NC}" >&2
        echo -e "${PURPLE}  - 预估内存: ${estimated_mb}MB${NC}" >&2
    fi

    echo "$estimated_mb"
}

# 创建临时目录函数
create_temp_dir() {
    # 检查临时目录是否存在且可写
    if [ ! -d "$TEMP_BASE_DIR" ]; then
        echo -e "${RED}❌ 临时目录不存在: $TEMP_BASE_DIR${NC}"
        exit 1
    fi

    if [ ! -w "$TEMP_BASE_DIR" ]; then
        echo -e "${RED}❌ 临时目录不可写: $TEMP_BASE_DIR${NC}"
        exit 1
    fi

    # 创建临时工作目录
    TEMP_DIR=$(mktemp -d -p "$TEMP_BASE_DIR" prep_dict.XXXXXX)

    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${PURPLE}🐛 临时目录: $TEMP_DIR${NC}"
        echo -e "${PURPLE}🐛 临时目录可用空间: $(df -h "$TEMP_BASE_DIR" | awk 'NR==2 {print $4}')${NC}"
    fi
}

# 清理函数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        if [ "$DEBUG_MODE" = true ]; then
            echo -e "${PURPLE}🐛 清理临时目录: $TEMP_DIR${NC}"
        fi
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# 主函数
main() {
    # 检查参数
    if [ $# -lt 2 ]; then
        show_usage
    fi

    COMMAND="$1"
    shift

    case "$COMMAND" in
        "clean")
            clean_dictionary "$@"
            ;;
        "merge")
            merge_dictionaries "$@"
            ;;
        "dedup")
            dedup_dictionary "$@"
            ;;
        "analyze")
            analyze_dictionary "$@"
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $COMMAND${NC}"
            show_usage
            ;;
    esac
}

# 字典清理函数
clean_dictionary() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ 用法: $0 clean <输入文件> [输出文件] [选项]${NC}"
        echo -e "${YELLOW}功能: 仅清理字典文件（移除非法字符、长度过滤），不进行去重${NC}"
        echo
        echo -e "${YELLOW}选项:${NC}"
        echo -e "  --keep-utf8       保留UTF-8字符（默认：移除）"
        echo -e "  --min-len=N       最小长度过滤（默认：8位）"
        echo -e "  --max-len=N       最大长度过滤（默认：63位）"
        echo -e "  --memory-ratio=N  内存使用比例（默认：0.6，即60%）"
        echo -e "  --jobs=N          并行CPU核心数（默认：自动检测）"
        echo -e "  --temp-dir=PATH   临时文件目录（默认：/tmp）"
        echo
        echo -e "${YELLOW}示例:${NC}"
        echo -e "  $0 clean raw.txt clean.txt --jobs=8"
        echo -e "  $0 clean chinese.txt --keep-utf8 --min-len=6"
        echo
        echo -e "${CYAN}💡 提示: 清理完成后如需去重，请使用: $0 dedup clean.txt${NC}"
        exit 1
    fi

    local input_file="$1"
    local output_file=""
    shift 1

    # 检查第二个参数是否是输出文件（不以--开头）
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        output_file="$1"
        shift 1
    fi

    # 如果没有指定输出文件，使用默认名称
    if [ -z "$output_file" ]; then
        output_file="${input_file%.*}_cleaned.txt"
    fi

    # 解析选项
    local PARALLEL_JOBS=$(nproc)

    while [ $# -gt 0 ]; do
        case "$1" in
            --keep-utf8)
                KEEP_UTF8=true
                ;;
            --jobs=*)
                PARALLEL_JOBS="${1#*=}"
                # 验证并行任务数范围
                if ! echo "$PARALLEL_JOBS" | grep -qE '^[1-9][0-9]*$'; then
                    echo -e "${RED}❌ 并行任务数必须是正整数${NC}"
                    exit 1
                fi
                if [ "$PARALLEL_JOBS" -gt 64 ]; then
                    echo -e "${YELLOW}⚠️  并行任务数过大，限制为64${NC}"
                    PARALLEL_JOBS=64
                fi
                ;;
            --min-len=*)
                MIN_LENGTH="${1#*=}"
                ;;
            --max-len=*)
                MAX_LENGTH="${1#*=}"
                ;;
            --memory-ratio=*)
                MEMORY_RATIO="${1#*=}"
                # 验证内存比例范围
                if ! echo "$MEMORY_RATIO" | grep -qE '^0\.[0-9]+$|^1\.0*$'; then
                    echo -e "${RED}❌ 内存比例必须在0.1-1.0之间${NC}"
                    exit 1
                fi
                ;;
            --debug)
                DEBUG_MODE=true
                ;;
            --no-examples)
                SHOW_EXAMPLES=false
                ;;
            --temp-dir=*)
                TEMP_BASE_DIR="${1#*=}"
                # 验证目录路径
                if [ ! -d "$TEMP_BASE_DIR" ]; then
                    echo -e "${RED}❌ 临时目录不存在: $TEMP_BASE_DIR${NC}"
                    exit 1
                fi
                if [ ! -w "$TEMP_BASE_DIR" ]; then
                    echo -e "${RED}❌ 临时目录不可写: $TEMP_BASE_DIR${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}❌ 未知选项: $1${NC}"
                exit 1
                ;;
        esac
        shift
    done

    # 显示配置信息
    local allowed_mem=$(calculate_memory_limit "$MEMORY_RATIO")
    echo -e "${CYAN}🧠 内存配置: 使用${MEMORY_RATIO}比例，允许使用${allowed_mem}MB内存${NC}"
    echo -e "${CYAN}⚡ 并行配置: 使用${PARALLEL_JOBS}个CPU核心${NC}"

    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${PURPLE}🐛 调试模式已启用${NC}"
        echo -e "${PURPLE}🐛 参数解析结果:${NC}"
        echo -e "${PURPLE}  - 输入文件: $input_file${NC}"
        echo -e "${PURPLE}  - 输出文件: $output_file${NC}"
        echo -e "${PURPLE}  - KEEP_UTF8: $KEEP_UTF8${NC}"
        echo -e "${PURPLE}  - MIN_LENGTH: $MIN_LENGTH${NC}"
        echo -e "${PURPLE}  - MAX_LENGTH: $MAX_LENGTH${NC}"
        echo -e "${PURPLE}  - MEMORY_RATIO: $MEMORY_RATIO${NC}"
        echo -e "${PURPLE}  - PARALLEL_JOBS: $PARALLEL_JOBS${NC}"
        echo -e "${PURPLE}  - TEMP_BASE_DIR: $TEMP_BASE_DIR${NC}"
        echo -e "${PURPLE}  - 系统可用内存: $(free -h | awk '/^Mem:/ {print $7}')${NC}"
        echo -e "${PURPLE}  - 系统CPU核心数: $(nproc)${NC}"
    fi

    # 创建临时工作目录
    create_temp_dir

    # 检查输入文件
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}❌ 输入文件不存在: $input_file${NC}"
        exit 1
    fi

    local input_size=$(du -h "$input_file" | cut -f1)
    echo -e "${CYAN}📁 输入文件: $input_file (大小: $input_size)${NC}"
    echo -e "${CYAN}🔤 UTF-8字符: $([ "$KEEP_UTF8" = true ] && echo "保留" || echo "移除")${NC}"

    echo -e "${YELLOW}🔍 检测文件类型...${NC}"
    local file_type=$(file "$input_file")
    echo -e "${BLUE}文件类型: $file_type${NC}"

    echo -e "${YELLOW}🧹 开始清理字典文件...${NC}"
    _process_file "$input_file" "$output_file" "$file_type"
}

# 核心文件处理函数
_process_file() {
    local input_file="$1"
    local output_file="$2" 
    local file_type="$3"
    
    local start_time=$(date +%s)
    
    # 显示系统资源
    echo -e "${BLUE}💻 系统资源: CPU核心=$(nproc), 可用内存=$(free -h | awk '/^Mem:/ {print $7}')${NC}"
    
    # 根据文件类型选择处理方法
    if [[ "$file_type" == *"data"* ]] || [[ "$file_type" == *"binary"* ]] || [[ "$file_type" == *"compressed"* ]]; then
        echo -e "${YELLOW}💽 检测到二进制数据文件，提取可打印字符串...${NC}"
        _process_binary_file "$input_file"
    else
        echo -e "${GREEN}📝 检测到文本文件，直接处理...${NC}"
        _process_text_file "$input_file"
    fi

    # 实时显示处理进度
    if [ -f "$TEMP_DIR/filtered.txt" ]; then
        (
            while [ ! -f "$output_file" ]; do
                if [ -f "$TEMP_DIR/filtered.txt" ]; then
                    local current_lines=$(wc -l < "$TEMP_DIR/filtered.txt" 2>/dev/null || echo "0")
                    echo -ne "\r${YELLOW}⏳ 已处理: $(printf "%'d" $current_lines) 行${NC}"
                fi
                sleep 2
            done
        ) &
        local progress_pid=$!
    fi

    # 检查过滤结果
    local filtered_count=$(wc -l < "$TEMP_DIR/filtered.txt" 2>/dev/null || echo "0")
    echo -e "${BLUE}📊 过滤后条目数: $(printf "%'d" $filtered_count)${NC}"

    if [ "$filtered_count" -eq 0 ]; then
        echo -e "${RED}❌ 没有找到有效的密码条目${NC}"
        exit 1
    fi

    # 直接输出过滤结果，不进行去重
    echo -e "${YELLOW}� 保存清理结果...${NC}"
    cp "$TEMP_DIR/filtered.txt" "$output_file"

    # 统计最终结果
    local final_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    local output_size=$(du -h "$output_file" | cut -f1)
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    local elapsed_formatted=$(format_time $elapsed_time)

    # 计算处理速度
    local processing_speed=0
    if [ "$elapsed_time" -gt 0 ]; then
        processing_speed=$((final_count / elapsed_time))
    fi

    echo
    echo -e "${GREEN}✅ 字典清理完成！${NC}"
    echo -e "${GREEN}📊 统计信息:${NC}"
    echo -e "${GREEN}  - 清理后条目数: $(printf "%'d" $final_count) 个${NC}"
    echo -e "${GREEN}  - 输出文件大小: $output_size${NC}"
    echo -e "${GREEN}  - 处理耗时: ${elapsed_formatted}${NC}"
    echo -e "${GREEN}  - 处理速度: $(printf "%'d" $processing_speed) 行/秒${NC}"
    echo -e "${GREEN}  - 保存位置: $output_file${NC}"

    # 可选的密码示例显示
    if [ "$SHOW_EXAMPLES" = true ]; then
        echo
        echo -e "${YELLOW}📋 清理后密码示例 (前10个):${NC}"
        head -10 "$output_file" | while read line; do
            echo -e "${BLUE}  • $line${NC}"
        done
    fi

    echo
    echo -e "${GREEN}🎉 清理完成！如需去重请使用: $0 dedup $output_file${NC}"

    [ -n "$progress_pid" ] && kill $progress_pid 2>/dev/null
}

# 处理二进制文件
_process_binary_file() {
    local input_file="$1"

    echo -e "${PURPLE}⏳ 提取字符串中...${NC}"
    timeout 300s strings "$input_file" 2>/dev/null | \
    _filter_passwords > "$TEMP_DIR/filtered.txt"
}

# 处理文本文件
_process_text_file() {
    local input_file="$1"

    # 获取文件行数来决定是否使用并行处理
    echo -e "${YELLOW}🔍 正在计算文件行数...${NC}"
    local file_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")
    echo -e "${BLUE}📊 文件行数: $(printf "%'d" $file_lines)${NC}"

    # 如果文件较小或只有1个CPU核心，使用单线程处理
    if [ "$file_lines" -lt 1000000 ] || [ "$PARALLEL_JOBS" -eq 1 ]; then
        echo -e "${PURPLE}🔧 单线程处理（文件行数: $(printf "%'d" $file_lines) < 1,000,000 或单核设置）...${NC}"
        _filter_passwords < "$input_file" > "$TEMP_DIR/filtered.txt"
    else
        echo -e "${PURPLE}⚡ 多线程并行处理（文件行数: $(printf "%'d" $file_lines) ≥ 1,000,000，使用${PARALLEL_JOBS}个线程）...${NC}"
        _parallel_process_text_file "$input_file" "$file_lines"
    fi
}

# 并行处理文本文件
_parallel_process_text_file() {
    local input_file="$1"
    local file_lines="$2"

    # 计算每个线程处理的行数
    local lines_per_job=$((file_lines / PARALLEL_JOBS))
    if [ "$lines_per_job" -lt 1000 ]; then
        lines_per_job=1000  # 最小块大小
    fi

    echo -e "${BLUE}📦 分块参数: 每个线程处理约${lines_per_job}行${NC}"

    # 分割文件
    split -l "$lines_per_job" "$input_file" "$TEMP_DIR/chunk_" --numeric-suffixes

    # 并行处理每个块
    local chunk_files=("$TEMP_DIR"/chunk_*)
    local pids=()
    local active_jobs=0

    echo -e "${YELLOW}🚀 启动并行任务，文件块数: ${#chunk_files[@]}，最大并行数: ${PARALLEL_JOBS}${NC}"

    for chunk in "${chunk_files[@]}"; do
        # 等待直到有空闲的进程槽位
        while [ "$active_jobs" -ge "$PARALLEL_JOBS" ]; do
            # 检查是否有进程完成
            local new_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                else
                    ((active_jobs--))
                fi
            done
            pids=("${new_pids[@]}")

            if [ "$active_jobs" -ge "$PARALLEL_JOBS" ]; then
                sleep 0.1  # 短暂等待
            fi
        done

        # 启动新的处理进程
        (
            local chunk_name=$(basename "$chunk")
            _filter_passwords < "$chunk" > "$TEMP_DIR/filtered_${chunk_name}.txt"
            rm -f "$chunk"  # 处理完立即删除原块节省空间
        ) &
        pids+=($!)
        ((active_jobs++))

        echo -e "${BLUE}📦 启动处理块: $(basename "$chunk")，当前活跃进程: ${active_jobs}/${PARALLEL_JOBS}${NC}"
    done

    # 等待所有任务完成
    echo -e "${YELLOW}⏳ 等待所有处理任务完成...${NC}"
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null
    done

    echo -e "${YELLOW}🔗 合并处理结果...${NC}"
    # 合并所有过滤结果
    cat "$TEMP_DIR"/filtered_chunk_*.txt > "$TEMP_DIR/filtered.txt"
    rm -f "$TEMP_DIR"/filtered_chunk_*.txt
}

# 优化_filter_passwords函数
_filter_passwords() {
    if [ "$KEEP_UTF8" = true ]; then
        # 使用单个awk命令完成所有过滤
        awk -v min="$MIN_LENGTH" -v max="$MAX_LENGTH" '
        {
            # 移除控制字符
            gsub(/[[:cntrl:]]/, "")
            # 检查长度和内容
            if (length($0) >= min && length($0) <= max && 
                $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:punct:]]*$/) {
                print
            }
        }'
    else
        # ASCII模式优化
        awk -v min="$MIN_LENGTH" -v max="$MAX_LENGTH" '
        length($0) >= min && length($0) <= max && 
        $0 ~ /^[[:print:]]*$/ && 
        $0 !~ /^[[:space:]]*$/ && 
        $0 !~ /^[[:punct:]]*$/ {
            print
        }'
    fi
}



# 合并字典函数
merge_dictionaries() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}❌ 用法: $0 merge <输出文件> <文件1> <文件2> [文件3...]${NC}"
        exit 1
    fi

    local output_file="$1"
    shift
    local input_files=("$@")

    # 检查输入文件
    for file in "${input_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ 错误: 文件 '$file' 不存在${NC}"
            exit 1
        fi
    done

    create_temp_dir
    local start_time=$(date +%s)

    echo -e "${CYAN}📁 合并 ${#input_files[@]} 个字典文件到: $output_file${NC}"
    echo

    # 显示输入文件信息
    local total_lines=0
    for file in "${input_files[@]}"; do
        local lines=$(wc -l < "$file" 2>/dev/null || echo "0")
        local size=$(du -h "$file" | cut -f1)
        echo -e "${BLUE}  • $file: $(printf "%'d" $lines) 行 ($size)${NC}"
        total_lines=$((total_lines + lines))
    done

    echo -e "${YELLOW}📊 总计: $(printf "%'d" $total_lines) 行${NC}"
    echo

    echo -e "${YELLOW}🔄 合并文件中...${NC}"

    # 仅合并文件，不进行去重处理
    cat "${input_files[@]}" > "$output_file"

    # 统计结果
    local final_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    local output_size=$(du -h "$output_file" | cut -f1)
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    local elapsed_formatted=$(format_time $elapsed_time)

    echo
    echo -e "${GREEN}✅ 合并完成！${NC}"
    echo -e "${GREEN}📊 统计信息:${NC}"
    echo -e "${GREEN}  - 原始总行数: $(printf "%'d" $total_lines) 行${NC}"
    echo -e "${GREEN}  - 合并后行数: $(printf "%'d" $final_count) 行${NC}"
    echo -e "${GREEN}  - 输出文件大小: $output_size${NC}"
    echo -e "${GREEN}  - 处理耗时: ${elapsed_formatted}${NC}"
    echo -e "${GREEN}  - 保存位置: $output_file${NC}"
    echo
    echo -e "${GREEN}🎉 合并完成！如需去重请使用: $0 dedup $output_file${NC}"
}

# 仅去重函数
dedup_dictionary() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ 用法: $0 dedup <输入文件> [输出文件] [选项]${NC}"
        echo -e "${YELLOW}功能: 仅去重处理，不进行内容清理或过滤${NC}"
        echo
        echo -e "${YELLOW}选项:${NC}"
        echo -e "  --memory-ratio=N  内存使用比例（默认：0.6，即60%）"
        echo -e "  --jobs=N          并行CPU核心数（默认：自动检测）"
        echo -e "  --temp-dir=PATH   临时文件目录（默认：/tmp）"
        echo
        echo -e "${YELLOW}示例:${NC}"
        echo -e "  $0 dedup input.txt output.txt --jobs=8"
        echo -e "  $0 dedup huge.txt --memory-ratio=0.3 --jobs=4"
        echo
        echo -e "${CYAN}💡 提示: 去重前如需清理，请先使用: $0 clean input.txt${NC}"
        exit 1
    fi

    local input_file="$1"
    local output_file=""
    shift 1

    # 检查第二个参数是否是输出文件（不以--开头）
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        output_file="$1"
        shift 1
    fi

    # 如果没有指定输出文件，使用默认名称
    if [ -z "$output_file" ]; then
        output_file="${input_file%.*}_dedup.txt"
    fi

    # 解析选项
    local PARALLEL_JOBS=$(nproc)

    while [ $# -gt 0 ]; do
        case "$1" in
            --jobs=*)
                PARALLEL_JOBS="${1#*=}"
                # 验证并行任务数范围
                if ! echo "$PARALLEL_JOBS" | grep -qE '^[1-9][0-9]*$'; then
                    echo -e "${RED}❌ 并行任务数必须是正整数${NC}"
                    exit 1
                fi
                if [ "$PARALLEL_JOBS" -gt 64 ]; then
                    echo -e "${YELLOW}⚠️  并行任务数过大，限制为64${NC}"
                    PARALLEL_JOBS=64
                fi
                ;;
            --memory-ratio=*)
                MEMORY_RATIO="${1#*=}"
                # 验证内存比例范围
                if ! echo "$MEMORY_RATIO" | grep -qE '^0\.[0-9]+$|^1\.0*$'; then
                    echo -e "${RED}❌ 内存比例必须在0.1-1.0之间${NC}"
                    exit 1
                fi
                ;;
            --temp-dir=*)
                TEMP_BASE_DIR="${1#*=}"
                # 验证目录路径
                if [ ! -d "$TEMP_BASE_DIR" ]; then
                    echo -e "${RED}❌ 临时目录不存在: $TEMP_BASE_DIR${NC}"
                    exit 1
                fi
                if [ ! -w "$TEMP_BASE_DIR" ]; then
                    echo -e "${RED}❌ 临时目录不可写: $TEMP_BASE_DIR${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}❌ 未知选项: $1${NC}"
                exit 1
                ;;
        esac
        shift
    done

    if [ ! -f "$input_file" ]; then
        echo -e "${RED}❌ 错误: 输入文件 '$input_file' 不存在${NC}"
        exit 1
    fi

    # 显示配置信息
    local allowed_mem=$(calculate_memory_limit "$MEMORY_RATIO")
    echo -e "${CYAN}🧠 内存配置: 使用${MEMORY_RATIO}比例，允许使用${allowed_mem}MB内存${NC}"
    echo -e "${CYAN}⚡ 并行配置: 使用${PARALLEL_JOBS}个CPU核心${NC}"

    # 创建临时工作目录
    create_temp_dir

    local start_time=$(date +%s)
    local input_size=$(du -h "$input_file" | cut -f1)
    local original_count=$(wc -l < "$input_file" 2>/dev/null || echo "0")

    echo -e "${CYAN}📁 输入文件: $input_file (大小: $input_size, 行数: $(printf "%'d" $original_count))${NC}"
    echo -e "${CYAN}📄 输出文件: $output_file${NC}"
    echo

    echo -e "${YELLOW}🔄 去重处理中...${NC}"

    # 检查当前内存使用情况
    check_memory_usage

    # 智能去重
    smart_dedup "$input_file" "$output_file"

    # 统计结果
    local final_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    local output_size=$(du -h "$output_file" | cut -f1)
    local duplicate_count=$((original_count - final_count))
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    local elapsed_formatted=$(format_time $elapsed_time)

    echo
    echo -e "${GREEN}✅ 去重完成！${NC}"
    echo -e "${GREEN}📊 统计信息:${NC}"
    echo -e "${GREEN}  - 原始行数: $(printf "%'d" $original_count) 行${NC}"
    echo -e "${GREEN}  - 最终行数: $(printf "%'d" $final_count) 行${NC}"
    echo -e "${GREEN}  - 移除重复项: $(printf "%'d" $duplicate_count) 行${NC}"
    local duplicate_rate=$(awk "BEGIN {printf \"%.2f%%\", $duplicate_count/$original_count*100}")
    echo -e "${GREEN}  - 重复率: ${duplicate_rate}${NC}"
    echo -e "${GREEN}  - 输出文件大小: $output_size${NC}"
    echo -e "${GREEN}  - 处理耗时: ${elapsed_formatted}${NC}"
    echo -e "${GREEN}  - 保存位置: $output_file${NC}"
    echo
    echo -e "${GREEN}🎉 去重完成！${NC}"
}

# 智能去重函数 - 根据内存限制选择策略
smart_dedup() {
    local input_file="$1"
    local output_file="$2"

    # 计算内存限制和预估需求
    local allowed_mem=$(calculate_memory_limit "$MEMORY_RATIO")
    local estimated_mem=$(estimate_dedup_memory "$input_file")
    local file_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")

    echo -e "${BLUE}📊 内存分析:${NC}"
    echo -e "${BLUE}  - 允许使用内存: ${allowed_mem}MB${NC}"
    echo -e "${BLUE}  - 预估需要内存: ${estimated_mem}MB${NC}"
    echo -e "${BLUE}  - 文件行数: $(printf "%'d" $file_lines)${NC}"

    # 智能选择去重策略 - 对大文件优先使用sort去重
    if [ "$file_lines" -gt 50000000 ]; then  # 超过5000万行，直接使用sort
        echo -e "${YELLOW}⚠️  大文件（>5000万行），使用sort去重策略${NC}"
        _dedup_huge_file_external_sort "$input_file" "$output_file" "$allowed_mem"
    elif [ "$estimated_mem" -gt $((allowed_mem * 80 / 100)) ]; then  # 预估内存超过允许内存的80%
        echo -e "${YELLOW}⚠️  预估内存需求过大（${estimated_mem}MB > ${allowed_mem}MB × 80%），使用sort去重${NC}"
        _dedup_huge_file_external_sort "$input_file" "$output_file" "$allowed_mem"
    else
        echo -e "${GREEN}✅ 小文件，使用快速内存去重${NC}"
        awk '!seen[$0]++' "$input_file" > "$output_file"
    fi
}

# 带内存限制的大文件去重
_dedup_large_file_with_memory_limit() {
    local input_file="$1"
    local output_file="$2"
    local allowed_mem_mb="$3"

    # 根据实际平均行长度计算块大小
    local avg_line_length
    if [ -f "$input_file" ]; then
        avg_line_length=$(head -1000 "$input_file" | awk '{sum += length($0); count++} END {printf "%.0f", sum/count}')
    fi
    if [ -z "$avg_line_length" ] || [ "$avg_line_length" -eq 0 ]; then
        avg_line_length=12  # 保守估计
    fi

    # 计算每行实际内存需求（字符串 + 哈希开销）
    local mem_per_line=$((avg_line_length + 80))  # 80字节哈希开销
    local chunk_lines=$((allowed_mem_mb * 1024 * 1024 / mem_per_line))

    # 设置合理的块大小限制
    if [ "$chunk_lines" -lt 500000 ]; then
        chunk_lines=500000  # 最小50万行
    fi
    if [ "$chunk_lines" -gt 100000000 ]; then
        chunk_lines=100000000  # 最大1亿行
    fi

    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${PURPLE}🐛 分块计算详情:${NC}"
        echo -e "${PURPLE}  - 平均行长度: ${avg_line_length}字符${NC}"
        echo -e "${PURPLE}  - 每行内存需求: ${mem_per_line}字节${NC}"
        echo -e "${PURPLE}  - 允许内存: ${allowed_mem_mb}MB${NC}"
        echo -e "${PURPLE}  - 计算块大小: $(printf "%'d" $chunk_lines)行${NC}"
    fi

    echo -e "${BLUE}📦 分块参数: 每块$(printf "%'d" $chunk_lines)行 (基于${allowed_mem_mb}MB内存限制)${NC}"
    
    # 分块处理
    split -l "$chunk_lines" "$input_file" "$TEMP_DIR/chunk_" --numeric-suffixes
    
    echo -e "${YELLOW}🔄 并行处理各块（${PARALLEL_JOBS}个线程）...${NC}"
    # 并行处理每个块，控制并发数
    local chunk_files=("$TEMP_DIR"/chunk_*)
    local pids=()

    for chunk in "${chunk_files[@]}"; do
        (
            awk '!seen[$0]++' "$chunk" > "${chunk}.dedup"
            rm -f "$chunk"  # 立即删除原块节省空间
        ) &
        pids+=($!)

        # 控制并发数
        if [ ${#pids[@]} -ge "$PARALLEL_JOBS" ]; then
            wait "${pids[@]}"
            pids=()
        fi
    done

    # 等待剩余任务完成
    if [ ${#pids[@]} -gt 0 ]; then
        wait "${pids[@]}"
    fi
    
    echo -e "${YELLOW}🔗 合并并最终去重...${NC}"
    # 合并并最终去重（这里可能还需要分块）
    local dedup_files=("$TEMP_DIR"/*.dedup)
    if [ ${#dedup_files[@]} -gt 10 ]; then
        # 如果去重后的块太多，再次分批合并
        _merge_dedup_files_in_batches "${dedup_files[@]}" "$output_file"
    else
        cat "$TEMP_DIR"/*.dedup | awk '!seen[$0]++' > "$output_file"
    fi
    
    rm -f "$TEMP_DIR"/*.dedup
}

# 分批合并去重文件
_merge_dedup_files_in_batches() {
    local output_file="${@: -1}"  # 最后一个参数是输出文件
    local files=("${@:1:$#-1}")   # 前面的参数是输入文件
    local batch_size=10
    local batch_num=0
    
    for ((i=0; i<${#files[@]}; i+=batch_size)); do
        local batch=("${files[@]:i:batch_size}")
        cat "${batch[@]}" | awk '!seen[$0]++' > "$TEMP_DIR/batch_$batch_num.tmp"
        ((batch_num++))
    done
    
    # 最终合并所有批次
    cat "$TEMP_DIR"/batch_*.tmp | awk '!seen[$0]++' > "$output_file"
    rm -f "$TEMP_DIR"/batch_*.tmp
}

# 超大文件外部排序去重（适用于10亿+行数据）
_dedup_huge_file_external_sort() {
    local input_file="$1"
    local output_file="$2"
    local allowed_mem_mb="$3"

    echo -e "${BLUE}🔄 使用外部排序去重策略（适合超大文件）${NC}"
    echo -e "${BLUE}📊 内存限制: ${allowed_mem_mb}MB${NC}"

    local file_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")

    # 如果文件超过50亿行，使用并行分块sort去重
    if [ "$file_lines" -gt 5000000000 ] && [ "$PARALLEL_JOBS" -gt 1 ]; then
        echo -e "${PURPLE}⚡ 超大文件（>50亿行），使用并行分块sort去重${NC}"
        _parallel_sort_dedup "$input_file" "$output_file" "$allowed_mem_mb"
    else
        echo -e "${PURPLE}🔧 使用单线程sort去重${NC}"
        _single_sort_dedup "$input_file" "$output_file" "$allowed_mem_mb"
    fi
}

# 单线程sort去重
_single_sort_dedup() {
    local input_file="$1"
    local output_file="$2"
    local allowed_mem_mb="$3"

    # sort命令实际使用的内存往往超过-S参数，保守设置为允许内存的70%
    local sort_buffer_size=$((allowed_mem_mb * 70 / 100))
    # 最小1GB，最大不超过允许内存
    if [ "$sort_buffer_size" -lt 1024 ]; then
        sort_buffer_size=1024
    fi
    if [ "$sort_buffer_size" -gt "$allowed_mem_mb" ]; then
        sort_buffer_size="$allowed_mem_mb"
    fi

    echo -e "${YELLOW}⏳ 正在排序并去重...${NC}"
    echo -e "${BLUE}📊 Sort参数: 内存缓冲区=${sort_buffer_size}M (保守设置为允许内存的70%), 临时目录=${TEMP_BASE_DIR}${NC}"

    # 使用sort的-u选项进行去重，-S指定内存缓冲区大小，-T指定临时目录
    if sort -u -S "${sort_buffer_size}M" -T "$TEMP_BASE_DIR" "$input_file" > "$output_file" 2>/dev/null; then
        echo -e "${GREEN}✅ 外部排序去重完成${NC}"
    else
        echo -e "${RED}❌ 外部排序失败，尝试分块处理...${NC}"
        _dedup_large_file_with_memory_limit "$input_file" "$output_file" "$allowed_mem_mb"
    fi
}

# 并行分块sort去重
_parallel_sort_dedup() {
    local input_file="$1"
    local output_file="$2"
    local allowed_mem_mb="$3"

    local file_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")

    # 计算每个线程处理的行数
    local lines_per_job=$((file_lines / PARALLEL_JOBS))
    if [ "$lines_per_job" -lt 10000000 ]; then
        lines_per_job=10000000  # 最小1000万行，确保分块有意义
    fi

    # 每个线程使用的内存（保守分配，考虑sort实际使用超出-S参数）
    local mem_per_job=$((allowed_mem_mb * 60 / 100 / PARALLEL_JOBS))  # 总内存的60%分给sort
    if [ "$mem_per_job" -lt 512 ]; then
        mem_per_job=512  # 最小512MB
    fi
    if [ "$mem_per_job" -gt 8192 ]; then
        mem_per_job=8192  # 最大8GB，避免单个sort进程占用过多内存
    fi

    echo -e "${BLUE}📦 并行分块参数:${NC}"
    echo -e "${BLUE}  - 总行数: $(printf "%'d" $file_lines)${NC}"
    echo -e "${BLUE}  - 每块行数: $(printf "%'d" $lines_per_job)${NC}"
    echo -e "${BLUE}  - 并行数: ${PARALLEL_JOBS}${NC}"
    echo -e "${BLUE}  - 每线程内存: ${mem_per_job}MB${NC}"
    echo -e "${BLUE}  - 临时目录: ${TEMP_BASE_DIR}${NC}"


    echo -e "${YELLOW}🔪 分割文件...${NC}"
    # 分割文件
    split -l "$lines_per_job" "$input_file" "$TEMP_DIR/chunk_" --numeric-suffixes

    echo -e "${YELLOW}⚡ 并行sort去重各块...${NC}"
    # 并行处理每个块
    local chunk_files=("$TEMP_DIR"/chunk_*)
    local pids=()
    local active_jobs=0

    for chunk in "${chunk_files[@]}"; do
        # 等待直到有空闲的进程槽位
        while [ "$active_jobs" -ge "$PARALLEL_JOBS" ]; do
            # 检查是否有进程完成
            local new_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                else
                    ((active_jobs--))
                fi
            done
            pids=("${new_pids[@]}")

            if [ "$active_jobs" -ge "$PARALLEL_JOBS" ]; then
                sleep 0.1  # 短暂等待
            fi
        done

        # 启动新的sort进程
        (
            local chunk_name=$(basename "$chunk")
            echo -e "${BLUE}📦 处理块: ${chunk_name}${NC}"
            sort -u -S "${mem_per_job}M" -T "$TEMP_BASE_DIR" "$chunk" > "$TEMP_DIR/sorted_${chunk_name}.txt"
            rm -f "$chunk"  # 处理完立即删除原块节省空间
        ) &
        pids+=($!)
        ((active_jobs++))

        echo -e "${BLUE}📦 启动sort块: $(basename "$chunk")，当前活跃进程: ${active_jobs}/${PARALLEL_JOBS}${NC}"
    done

    # 等待所有任务完成
    echo -e "${YELLOW}⏳ 等待所有sort任务完成...${NC}"
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null
    done

    echo -e "${YELLOW}🔗 合并已排序的块...${NC}"
    # 合并所有已排序的块，使用sort -m进行高效合并
    local sorted_files=("$TEMP_DIR"/sorted_chunk_*.txt)
    if [ ${#sorted_files[@]} -gt 1 ]; then
        # 合并阶段使用更保守的内存设置（50%）
        local merge_mem=$((allowed_mem_mb * 50 / 100))
        if [ "$merge_mem" -lt 2048 ]; then
            merge_mem=2048  # 最小2GB
        fi
        echo -e "${BLUE}📊 合并参数: 内存缓冲区=${merge_mem}M (保守设置为允许内存的50%)${NC}"
        # 使用sort -m -u合并多个已排序文件并去重
        sort -m -u -S "${merge_mem}M" -T "$TEMP_BASE_DIR" "${sorted_files[@]}" > "$output_file"
    else
        # 只有一个文件，直接复制
        cp "${sorted_files[0]}" "$output_file"
    fi

    # 清理临时文件
    rm -f "$TEMP_DIR"/sorted_chunk_*.txt

    echo -e "${GREEN}✅ 并行sort去重完成${NC}"
}

# 分析字典函数
analyze_dictionary() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}❌ 用法: $0 analyze <文件>${NC}"
        exit 1
    fi

    local input_file="$1"

    if [ ! -f "$input_file" ]; then
        echo -e "${RED}❌ 错误: 文件 '$input_file' 不存在${NC}"
        exit 1
    fi

    local start_time=$(date +%s)
    echo -e "${CYAN}📊 开始分析字典文件: $input_file${NC}"
    echo

    # 基本信息
    local file_size=$(du -h "$input_file" | cut -f1)
    local total_lines=$(wc -l < "$input_file" 2>/dev/null || echo "0")
    local file_type=$(file "$input_file" 2>/dev/null)

    echo -e "${YELLOW}📁 基本信息:${NC}"
    echo -e "${BLUE}  • 文件大小: $file_size${NC}"
    echo -e "${BLUE}  • 总行数: $(printf "%'d" $total_lines)${NC}"
    echo -e "${BLUE}  • 文件类型: $file_type${NC}"
    echo

    # 长度分布
    echo -e "${YELLOW}📏 长度分布:${NC}"
    awk '{print length($0)}' "$input_file" | awk '{count[$1]++} END {for (i in count) printf "%d %d\n", i, count[i]}' | \
    while read length count; do
        percentage=$(awk "BEGIN {printf \"%.1f%%\", $count/$total_lines*100}")
        echo -e "${BLUE}  • $length 位: $(printf "%'d" $count) 个 ($percentage)${NC}"
    done | head -15
    echo

    # 字符集分析
    echo -e "${YELLOW}🔤 字符集分析:${NC}"
    local ascii_only=$(grep -c '^[[:print:]]*$' "$input_file" 2>/dev/null || echo "0")
    local has_numbers=$(grep -c '[0-9]' "$input_file" 2>/dev/null || echo "0")
    local has_letters=$(grep -c '[a-zA-Z]' "$input_file" 2>/dev/null || echo "0")
    local has_symbols=$(grep -c '[[:punct:]]' "$input_file" 2>/dev/null || echo "0")
    local has_spaces=$(grep -c '[[:space:]]' "$input_file" 2>/dev/null || echo "0")

    echo -e "${BLUE}  • 纯ASCII: $(printf "%'d" $ascii_only) 个 ($(awk "BEGIN {printf \"%.1f%%\", $ascii_only/$total_lines*100}"))${NC}"
    echo -e "${BLUE}  • 包含数字: $(printf "%'d" $has_numbers) 个 ($(awk "BEGIN {printf \"%.1f%%\", $has_numbers/$total_lines*100}"))${NC}"
    echo -e "${BLUE}  • 包含字母: $(printf "%'d" $has_letters) 个 ($(awk "BEGIN {printf \"%.1f%%\", $has_letters/$total_lines*100}"))${NC}"
    echo -e "${BLUE}  • 包含符号: $(printf "%'d" $has_symbols) 个 ($(awk "BEGIN {printf \"%.1f%%\", $has_symbols/$total_lines*100}"))${NC}"
    echo -e "${BLUE}  • 包含空格: $(printf "%'d" $has_spaces) 个 ($(awk "BEGIN {printf \"%.1f%%\", $has_spaces/$total_lines*100}"))${NC}"
    echo

    # WiFi密码有效性
    echo -e "${YELLOW}📶 WiFi密码有效性:${NC}"
    local valid_wifi=$(grep -E '^[[:print:]]{8,63}$' "$input_file" | grep -v '[[:space:]]' | wc -l 2>/dev/null || echo "0")
    local too_short=$(awk 'length($0) < 8' "$input_file" | wc -l 2>/dev/null || echo "0")
    local too_long=$(awk 'length($0) > 63' "$input_file" | wc -l 2>/dev/null || echo "0")

    echo -e "${BLUE}  • 有效WiFi密码: $(printf "%'d" $valid_wifi) 个 ($(awk "BEGIN {printf \"%.1f%%\", $valid_wifi/$total_lines*100}"))${NC}"
    echo -e "${BLUE}  • 过短(<8位): $(printf "%'d" $too_short) 个 ($(awk "BEGIN {printf \"%.1f%%\", $too_short/$total_lines*100}"))${NC}"
    echo -e "${BLUE}  • 过长(>63位): $(printf "%'d" $too_long) 个 ($(awk "BEGIN {printf \"%.1f%%\", $too_long/$total_lines*100}"))${NC}"
    echo

    # 重复率分析
    echo -e "${YELLOW}🔄 重复率分析:${NC}"
    local unique_count=$(awk '!seen[$0]++' "$input_file" | wc -l 2>/dev/null || echo "0")
    local duplicate_count=$((total_lines - unique_count))
    local duplicate_rate=$(awk "BEGIN {printf \"%.2f%%\", $duplicate_count/$total_lines*100}")

    echo -e "${BLUE}  • 唯一条目: $(printf "%'d" $unique_count) 个${NC}"
    echo -e "${BLUE}  • 重复条目: $(printf "%'d" $duplicate_count) 个${NC}"
    echo -e "${BLUE}  • 重复率: $duplicate_rate${NC}"
    echo

    # 常见密码示例
    echo -e "${YELLOW}📋 常见密码示例:${NC}"
    head -20 "$input_file" | while read line; do
        echo -e "${BLUE}  • $line${NC}"
    done
    echo

    # 建议
    echo -e "${YELLOW}💡 优化建议:${NC}"
    if [ "$duplicate_count" -gt 0 ]; then
        echo -e "${BLUE}  • 建议去重: ./prep_dictionary.sh dedup '$input_file'${NC}"
    fi
    if [ "$too_short" -gt 0 ] || [ "$too_long" -gt 0 ] || [ "$has_spaces" -gt 0 ]; then
        echo -e "${BLUE}  • 建议清理: ./prep_dictionary.sh clean '$input_file'${NC}"
    fi
    if [ "$valid_wifi" -lt "$((total_lines * 80 / 100))" ]; then
        echo -e "${BLUE}  • 有效密码比例较低，建议清理无效条目${NC}"
    fi

    # 计算并显示耗时
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    local elapsed_formatted=$(format_time $elapsed_time)

    echo
    echo -e "${GREEN}✅ 分析完成！${NC}"
    echo -e "${GREEN}📊 分析耗时: ${elapsed_formatted}${NC}"
}

# 启动主程序
main "$@"
