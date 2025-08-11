#!/bin/bash

# 高效手机号码字典生成脚本 (合并优化版)
# 用法: ./gen_phone_dic.sh phone_segments.csv
# 功能: 根据CSV文件中的7位数号段，在每个7位数后添加0000-9999生成完整的11位手机号码字典
# 特点: 高效生成 + 完整城市支持 + 友好进度显示

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <csv文件名>"
    echo "示例: $0 phone_segments.csv"
    exit 1
fi

CSV_FILE="$1"

# 检查CSV文件是否存在
if [ ! -f "$CSV_FILE" ]; then
    echo "错误: 文件 $CSV_FILE 不存在"
    exit 1
fi

# 检查CSV文件是否有内容
if [ ! -s "$CSV_FILE" ]; then
    echo "错误: 文件 $CSV_FILE 为空"
    exit 1
fi

# 城市汉字到拼音的映射函数 (完整版)
get_city_pinyin() {
    local city_chinese="$1"
    case "$city_chinese" in
        # 直辖市
        "北京") echo "beijing" ;;
        "天津") echo "tianjin" ;;
        "上海") echo "shanghai" ;;
        "重庆") echo "chongqing" ;;

        # 山东省
        "济南") echo "jinan" ;;
        "淄博") echo "zibo" ;;
        "烟台") echo "yantai" ;;
        "潍坊") echo "weifang" ;;
        "滨州") echo "binzhou" ;;
        "东营") echo "dongying" ;;
        "临沂") echo "linyi" ;;
        "日照") echo "rizhao" ;;
        "枣庄") echo "zaozhuang" ;;
        "威海") echo "weihai" ;;
        "青岛") echo "qingdao" ;;
        "聊城") echo "liaocheng" ;;
        "德州") echo "dezhou" ;;
        "泰安") echo "taian" ;;
        "济宁") echo "jining" ;;
        "菏泽") echo "heze" ;;

        # 江苏省
        "常州") echo "changzhou" ;;
        "南京") echo "nanjing" ;;
        "无锡") echo "wuxi" ;;
        "镇江") echo "zhenjiang" ;;
        "连云港") echo "lianyungang" ;;
        "盐城") echo "yancheng" ;;
        "宿迁") echo "suqian" ;;
        "徐州") echo "xuzhou" ;;
        "南通") echo "nantong" ;;
        "淮安") echo "huaian" ;;
        "扬州") echo "yangzhou" ;;
        "泰州") echo "taizhou" ;;
        "苏州") echo "suzhou" ;;

        # 安徽省
        "合肥") echo "hefei" ;;
        "蚌埠") echo "bengbu" ;;
        "芜湖") echo "wuhu" ;;
        "淮南") echo "huainan" ;;
        "阜阳") echo "fuyang" ;;
        "马鞍山") echo "maanshan" ;;
        "宣城") echo "xuancheng" ;;
        "安庆") echo "anqing" ;;
        "滁州") echo "chuzhou" ;;
        "池州") echo "chizhou" ;;
        "黄山") echo "huangshan" ;;
        "铜陵") echo "tongling" ;;
        "宿州") echo "suzhou" ;;
        "六安") echo "luan" ;;
        "淮北") echo "huaibei" ;;
        "亳州") echo "bozhou" ;;

        # 四川省
        "宜宾") echo "yibin" ;;
        "自贡") echo "zigong" ;;
        "西昌") echo "xichang" ;;
        "攀枝花") echo "panzhihua" ;;
        "南充") echo "nanchong" ;;
        "遂宁") echo "suining" ;;
        "达州") echo "dazhou" ;;
        "泸州") echo "luzhou" ;;
        "内江") echo "neijiang" ;;
        "乐山") echo "leshan" ;;
        "眉山") echo "meishan" ;;
        "德阳") echo "deyang" ;;
        "广元") echo "guangyuan" ;;
        "绵阳") echo "mianyang" ;;
        "成都") echo "chengdu" ;;
        "资阳") echo "ziyang" ;;
        "甘孜") echo "ganzi" ;;
        "阿坝") echo "aba" ;;
        "巴中") echo "bazhong" ;;
        "广安") echo "guangan" ;;
        "雅安") echo "yaan" ;;
        "凉山") echo "liangshan" ;;
        "达川") echo "dachuan" ;;
        "康定") echo "kangding" ;;
        "成都/眉山/资阳") echo "chengdu_meishan_ziyang" ;;

        # 陕西省
        "西安") echo "xian" ;;
        "渭南") echo "weinan" ;;
        "咸阳") echo "xianyang" ;;
        "汉中") echo "hanzhong" ;;
        "宝鸡") echo "baoji" ;;
        "铜川") echo "tongchuan" ;;
        "延安") echo "yanan" ;;
        "榆林") echo "yulin" ;;
        "商洛") echo "shangluo" ;;
        "安康") echo "ankang" ;;
        "商州") echo "shangzhou" ;;

        # 湖北省
        "武汉") echo "wuhan" ;;
        "荆门") echo "jingmen" ;;
        "宜昌") echo "yichang" ;;
        "恩施") echo "enshi" ;;
        "黄石") echo "huangshi" ;;
        "鄂州") echo "ezhou" ;;
        "黄冈") echo "huanggang" ;;
        "孝感") echo "xiaogan" ;;
        "随州") echo "suizhou" ;;
        "襄阳") echo "xiangyang" ;;
        "十堰") echo "shiyan" ;;
        "荆州") echo "jingzhou" ;;
        "仙桃") echo "xiantao" ;;
        "咸宁") echo "xianning" ;;
        "江汉") echo "jianghan" ;;
        "神农架") echo "shennongjia" ;;
        "潜江") echo "qianjiang" ;;

        # 广东省
        "广州") echo "guangzhou" ;;
        "汕头") echo "shantou" ;;
        "汕尾") echo "shanwei" ;;
        "揭阳") echo "jieyang" ;;
        "梅州") echo "meizhou" ;;
        "河源") echo "heyuan" ;;
        "潮州") echo "chaozhou" ;;
        "清远") echo "qingyuan" ;;
        "韶关") echo "shaoguan" ;;
        "云浮") echo "yunfu" ;;
        "深圳") echo "shenzhen" ;;
        "中山") echo "zhongshan" ;;
        "肇庆") echo "zhaoqing" ;;
        "湛江") echo "zhanjiang" ;;
        "阳江") echo "yangjiang" ;;
        "茂名") echo "maoming" ;;
        "珠海") echo "zhuhai" ;;
        "惠州") echo "huizhou" ;;
        "江门") echo "jiangmen" ;;
        "佛山") echo "foshan" ;;
        "东莞") echo "dongguan" ;;

        # 广西壮族自治区
        "南宁") echo "nanning" ;;
        "柳州") echo "liuzhou" ;;
        "桂林") echo "guilin" ;;
        "玉林") echo "yulin" ;;
        "梧州") echo "wuzhou" ;;
        "北海") echo "beihai" ;;
        "防城港") echo "fangchenggang" ;;
        "百色") echo "baise" ;;
        "钦州") echo "qinzhou" ;;
        "河池") echo "hechi" ;;
        "贵港") echo "guigang" ;;
        "贺州") echo "hezhou" ;;
        "来宾") echo "laibin" ;;
        "崇左") echo "chongzuo" ;;

        # 浙江省
        "温州") echo "wenzhou" ;;
        "宁波") echo "ningbo" ;;
        "嘉兴") echo "jiaxing" ;;
        "湖州") echo "huzhou" ;;
        "舟山") echo "zhoushan" ;;
        "绍兴") echo "shaoxing" ;;
        "衢州") echo "quzhou" ;;
        "金华") echo "jinhua" ;;
        "台州") echo "taizhou" ;;
        "丽水") echo "lishui" ;;
        "杭州") echo "hangzhou" ;;

        # 河南省
        "郑州") echo "zhengzhou" ;;
        "洛阳") echo "luoyang" ;;
        "安阳") echo "anyang" ;;
        "开封") echo "kaifeng" ;;
        "焦作") echo "jiaozuo" ;;
        "新乡") echo "xinxiang" ;;
        "许昌") echo "xuchang" ;;
        "漯河") echo "luohe" ;;
        "平顶山") echo "pingdingshan" ;;
        "济源") echo "jiyuan" ;;
        "濮阳") echo "puyang" ;;
        "三门峡") echo "sanmenxia" ;;
        "鹤壁") echo "hebi" ;;
        "信阳") echo "xinyang" ;;
        "驻马店") echo "zhumadian" ;;
        "周口") echo "zhoukou" ;;
        "商丘") echo "shangqiu" ;;
        "南阳") echo "nanyang" ;;
        "郑州/开封") echo "zhengzhou_kaifeng" ;;

        # 甘肃省
        "兰州") echo "lanzhou" ;;
        "嘉峪关") echo "jiayuguan" ;;
        "张掖") echo "zhangye" ;;
        "武威") echo "wuwei" ;;
        "白银") echo "baiyin" ;;
        "酒泉") echo "jiuquan" ;;
        "定西") echo "dingxi" ;;
        "临夏") echo "linxia" ;;
        "庆阳") echo "qingyang" ;;
        "天水") echo "tianshui" ;;
        "平凉") echo "pingliang" ;;
        "甘南") echo "gannan" ;;
        "陇南") echo "longnan" ;;
        "金昌") echo "jinchang" ;;

        # 吉林省
        "长春") echo "changchun" ;;
        "四平") echo "siping" ;;
        "辽源") echo "liaoyuan" ;;
        "松原") echo "songyuan" ;;
        "白城") echo "baicheng" ;;
        "白山") echo "baishan" ;;
        "延边") echo "yanbian" ;;
        "吉林") echo "jilin" ;;
        "通化") echo "tonghua" ;;
        "梅河口") echo "meihekou" ;;
        "延吉") echo "yanji" ;;
        "珲春") echo "hunchun" ;;

        # 辽宁省
        "本溪") echo "benxi" ;;
        "营口") echo "yingkou" ;;
        "大连") echo "dalian" ;;
        "沈阳") echo "shenyang" ;;
        "辽阳") echo "liaoyang" ;;
        "阜新") echo "fuxin" ;;
        "盘锦") echo "panjin" ;;
        "朝阳") echo "chaoyang" ;;
        "锦州") echo "jinzhou" ;;
        "铁岭") echo "tieling" ;;
        "丹东") echo "dandong" ;;
        "抚顺") echo "fushun" ;;
        "葫芦岛") echo "huludao" ;;
        "鞍山") echo "anshan" ;;
        "沈阳/铁岭/抚顺/本溪") echo "shenyang_tieling_fushun_benxi" ;;

        # 内蒙古自治区
        "包头") echo "baotou" ;;
        "呼和浩特") echo "huhehaote" ;;
        "乌兰察布") echo "wulanchabu" ;;
        "鄂尔多斯") echo "eerduosi" ;;
        "巴彦淖尔") echo "bayannaoer" ;;
        "乌海") echo "wuhai" ;;
        "海拉尔") echo "hailaer" ;;
        "通辽") echo "tongliao" ;;
        "赤峰") echo "chifeng" ;;
        "兴安") echo "xingan" ;;
        "锡林郭勒") echo "xilinguole" ;;
        "阿拉善") echo "alashan" ;;
        "锡林浩特") echo "xilinhaote" ;;
        "呼伦贝尔") echo "hulunbeier" ;;
        "乌兰浩特") echo "wulanhaote" ;;
        "临河") echo "linhe" ;;
        "集宁") echo "jining" ;;

        # 新疆维吾尔自治区
        "乌鲁木齐") echo "wulumuqi" ;;
        "昌吉") echo "changji" ;;
        "石河子") echo "shihezi" ;;
        "库尔勒") echo "kuerle" ;;
        "喀什") echo "kashi" ;;
        "吐鲁番") echo "tulufan" ;;
        "哈密") echo "hami" ;;
        "阿克苏") echo "akesu" ;;
        "奎屯") echo "kuitun" ;;
        "博乐") echo "bole" ;;
        "伊犁") echo "yili" ;;
        "克拉玛依") echo "kelamayi" ;;
        "克孜勒苏") echo "kezilesu" ;;
        "和田") echo "hetian" ;;
        "塔城") echo "tacheng" ;;
        "阿勒泰") echo "aletai" ;;
        "巴音郭楞") echo "bayinguoleng" ;;
        "博尔塔拉") echo "boertala" ;;

        # 黑龙江省
        "佳木斯") echo "jiamusi" ;;
        "哈尔滨") echo "haerbin" ;;
        "齐齐哈尔") echo "qiqihaer" ;;
        "牡丹江") echo "mudanjiang" ;;
        "大庆") echo "daqing" ;;
        "绥化") echo "suihua" ;;
        "黑河") echo "heihe" ;;
        "鸡西") echo "jixi" ;;
        "七台河") echo "qitaihe" ;;
        "鹤岗") echo "hegang" ;;
        "双鸭山") echo "shuangyashan" ;;
        "伊春") echo "yichun" ;;
        "大兴安岭") echo "daxinganling" ;;

        # 福建省
        "福州") echo "fuzhou" ;;
        "莆田") echo "putian" ;;
        "厦门") echo "xiamen" ;;
        "漳州") echo "zhangzhou" ;;
        "泉州") echo "quanzhou" ;;
        "三明") echo "sanming" ;;
        "宁德") echo "ningde" ;;
        "南平") echo "nanping" ;;
        "龙岩") echo "longyan" ;;

        # 河北省
        "保定") echo "baoding" ;;
        "唐山") echo "tangshan" ;;
        "秦皇岛") echo "qinhuangdao" ;;
        "廊坊") echo "langfang" ;;
        "沧州") echo "cangzhou" ;;
        "邢台") echo "xingtai" ;;
        "邯郸") echo "handan" ;;
        "衡水") echo "hengshui" ;;
        "石家庄") echo "shijiazhuang" ;;
        "张家口") echo "zhangjiakou" ;;
        "承德") echo "chengde" ;;
        "雄安") echo "xiongan" ;;

        # 重庆市（区县）
        "黔江") echo "qianjiang" ;;
        "万州") echo "wanzhou" ;;
        "涪陵") echo "fuling" ;;

        # 海南省
        "海口") echo "haikou" ;;
        "三亚") echo "sanya" ;;

        # 江西省
        "南昌") echo "nanchang" ;;
        "鹰潭") echo "yingtan" ;;
        "上饶") echo "shangrao" ;;
        "宜春") echo "yichun" ;;
        "新余") echo "xinyu" ;;
        "萍乡") echo "pingxiang" ;;
        "九江") echo "jiujiang" ;;
        "赣州") echo "ganzhou" ;;
        "景德镇") echo "jingdezhen" ;;
        "吉安") echo "jian" ;;
        "抚州") echo "fuzhou" ;;

        # 山西省
        "太原") echo "taiyuan" ;;
        "晋中") echo "jinzhong" ;;
        "运城") echo "yuncheng" ;;
        "临汾") echo "linfen" ;;
        "大同") echo "datong" ;;
        "晋城") echo "jincheng" ;;
        "长治") echo "changzhi" ;;
        "忻州") echo "xinzhou" ;;
        "朔州") echo "shuozhou" ;;
        "吕梁") echo "lvliang" ;;
        "阳泉") echo "yangquan" ;;

        # 湖南省
        "岳阳") echo "yueyang" ;;
        "长沙") echo "changsha" ;;
        "湘潭") echo "xiangtan" ;;
        "株洲") echo "zhuzhou" ;;
        "衡阳") echo "hengyang" ;;
        "郴州") echo "chenzhou" ;;
        "常德") echo "changde" ;;
        "益阳") echo "yiyang" ;;
        "娄底") echo "loudi" ;;
        "邵阳") echo "shaoyang" ;;
        "怀化") echo "huaihua" ;;
        "张家界") echo "zhangjiajie" ;;
        "永州") echo "yongzhou" ;;
        "吉首") echo "jishou" ;;
        "湘西") echo "xiangxi" ;;
        "长沙/湘潭/株洲") echo "changsha_xiangtan_zhuzhou" ;;

        # 青海省
        "格尔木") echo "geermu" ;;
        "西宁") echo "xining" ;;
        "海东") echo "haidong" ;;
        "海南") echo "hainan" ;;
        "海北") echo "haibei" ;;
        "海西") echo "haixi" ;;
        "玉树") echo "yushu" ;;
        "果洛") echo "guoluo" ;;
        "黄南") echo "huangnan" ;;
        "海晏") echo "haiyan" ;;
        "共和") echo "gonghe" ;;
        "德令哈") echo "delingha" ;;

        # 贵州省
        "贵阳") echo "guiyang" ;;
        "遵义") echo "zunyi" ;;
        "安顺") echo "anshun" ;;
        "铜仁") echo "tongren" ;;
        "黔东南") echo "qiandongnan" ;;
        "黔南") echo "qiannan" ;;
        "六盘水") echo "liupanshui" ;;
        "黔西南") echo "qianxinan" ;;
        "毕节") echo "bijie" ;;
        "都匀") echo "duyun" ;;
        "凯里") echo "kaili" ;;
        "兴义") echo "xingyi" ;;
        "贵阳/遵义/安顺") echo "guiyang_zunyi_anshun" ;;

        # 宁夏回族自治区
        "石嘴山") echo "shizuishan" ;;
        "吴忠") echo "wuzhong" ;;
        "固原") echo "guyuan" ;;
        "银川") echo "yinchuan" ;;
        "中卫") echo "zhongwei" ;;

        # 云南省
        "红河") echo "honghe" ;;
        "楚雄") echo "chuxiong" ;;
        "曲靖") echo "qujing" ;;
        "玉溪") echo "yuxi" ;;
        "昆明") echo "kunming" ;;
        "大理") echo "dali" ;;
        "丽江") echo "lijiang" ;;
        "文山") echo "wenshan" ;;
        "普洱") echo "puer" ;;
        "保山") echo "baoshan" ;;
        "临沧") echo "lincang" ;;
        "怒江") echo "nujiang" ;;
        "德宏") echo "dehong" ;;
        "西双版纳") echo "xishuangbanna" ;;
        "迪庆") echo "diqing" ;;
        "昭通") echo "zhaotong" ;;
        "思茅") echo "simao" ;;

        # 西藏自治区
        "拉萨") echo "lasa" ;;
        "日喀则") echo "rikaze" ;;
        "山南") echo "shannan" ;;
        "林芝") echo "linzhi" ;;
        "昌都") echo "changdu" ;;
        "那曲") echo "naqu" ;;
        "阿里") echo "ali" ;;

        # 港澳台
        "台北") echo "taibei" ;;
        "香港") echo "xianggang" ;;
        "澳门") echo "aomen" ;;

        *)
            # 如果没有映射，使用原始城市名并给出警告
            echo "警告: 未找到城市 '$city_chinese' 的拼音映射，使用原名" >&2
            echo "$city_chinese"
            ;;
    esac
}

# 获取城市名（从CSV第一行数据中提取）
CITY_NAME=$(tail -n +2 "$CSV_FILE" | head -n 1 | cut -d',' -f1)

if [ -z "$CITY_NAME" ]; then
    echo "错误: 无法从CSV文件中提取城市名"
    exit 1
fi

# 获取城市拼音
CITY_PINYIN=$(get_city_pinyin "$CITY_NAME")

echo "开始为城市 $CITY_NAME ($CITY_PINYIN) 生成手机号码字典..."

# 输出文件名（城市名全拼.txt）
OUTPUT_FILE="${CITY_PINYIN}.txt"

# 如果输出文件已存在，询问是否覆盖
if [ -f "$OUTPUT_FILE" ]; then
    echo "警告: 文件 $OUTPUT_FILE 已存在"
    read -p "是否覆盖? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 0
    fi
fi

echo "提取7位数号段..."
# 提取所有7位数号段（去重并清理回车符）
SEGMENTS=$(tail -n +2 "$CSV_FILE" | cut -d',' -f4 | tr -d '\r' | sort | uniq)

# 统计号段数量
SEGMENT_COUNT=$(echo "$SEGMENTS" | wc -l)
echo "找到 $SEGMENT_COUNT 个唯一的7位数号段"

# 计算总生成数量
TOTAL_COUNT=$((SEGMENT_COUNT * 10000))
echo "将生成 $TOTAL_COUNT 个手机号码"

# 增强的进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local bar_length=40
    local filled_length=$((percent * bar_length / 100))

    # 计算剩余时间估算
    if [ $current -gt 0 ] && [ -n "$start_time" ]; then
        local elapsed=$(($(date +%s) - start_time))
        if [ $elapsed -gt 0 ]; then
            local rate=$((current * 1000 / elapsed))  # 使用毫秒精度
            if [ $rate -gt 0 ]; then
                local remaining=$(((total - current) * 1000 / rate))
                local eta_min=$((remaining / 60))
                local eta_sec=$((remaining % 60))
                local eta_str=""
                if [ $eta_min -gt 0 ]; then
                    eta_str=" ETA: ${eta_min}m${eta_sec}s"
                else
                    eta_str=" ETA: ${eta_sec}s"
                fi
            else
                local eta_str=""
            fi
        else
            local eta_str=""
        fi
    else
        local eta_str=""
    fi

    printf "\r["
    for ((i=0; i<filled_length; i++)); do printf "█"; done
    for ((i=filled_length; i<bar_length; i++)); do printf "░"; done
    printf "] %3d%% (%d/%d)%s" "$percent" "$current" "$total" "$eta_str"
}

# 清空输出文件
> "$OUTPUT_FILE"

# 使用高效方式生成字典
echo "开始生成手机号码字典..."
echo

# 记录开始时间
start_time=$(date +%s)

# 使用进度计数
current=0
for segment in $SEGMENTS; do
    current=$((current + 1))
    
    # 显示进度 (每10个号段或最后一个显示)
    if [ $((current % 10)) -eq 0 ] || [ $current -eq $SEGMENT_COUNT ]; then
        show_progress $current $SEGMENT_COUNT
    fi
    
    # 使用seq和printf批量生成，提高效率 (来自fast版本的优化)
    seq -f "${segment}%04.0f" 0 9999 >> "$OUTPUT_FILE"
done

echo
echo
echo "字典生成完成!"
echo "输出文件: $OUTPUT_FILE"

# 显示文件信息
if [ -f "$OUTPUT_FILE" ]; then
    ACTUAL_COUNT=$(wc -l < "$OUTPUT_FILE")
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "实际生成的手机号码数量: $ACTUAL_COUNT"
    echo "文件大小: $FILE_SIZE"
    
    # 计算总耗时
    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    echo "总耗时: ${total_time}秒"
    
    # 计算生成速度
    if [ $total_time -gt 0 ]; then
        speed=$((ACTUAL_COUNT / total_time))
        echo "生成速度: ${speed} 号码/秒"
    fi
    
    # 显示前几行和后几行作为预览
    echo
    echo "文件预览 (前5行):"
    head -n 5 "$OUTPUT_FILE"
    echo "..."
    echo "文件预览 (后5行):"
    tail -n 5 "$OUTPUT_FILE"
fi

echo
echo "字典文件已保存为: $OUTPUT_FILE"
