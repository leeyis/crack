# 手机号段爬虫使用说明

## 功能更新

### 新增功能
1. **多城市支持**: 支持一次性传入多个城市名字
2. **自动文件命名**: 按城市名自动生成文件名（城市全拼+phone_segments.csv）
3. **重复数据去除**: 在多个层面进行去重，确保数据唯一性
4. **增强网络稳定性**: 改进重试机制和超时设置

### 去重机制
1. **3位号段去重**: 在提取3位号段时去除重复
2. **7位号段去重**: 在保存CSV时基于7位号段进行最终去重
3. **详细日志**: 显示去重前后的数据量对比

## 使用方法

### 1. 单个城市
```bash
python3 phone_segment_crawler.py --city 武汉
# 输出文件: wuhan_phone_segments.csv
```

### 2. 多个城市（推荐）
```bash
python3 phone_segment_crawler.py --cities 武汉 宜昌 襄阳
# 输出文件: 
#   wuhan_phone_segments.csv
#   yichang_phone_segments.csv  
#   xiangyang_phone_segments.csv
```

### 3. 使用配置文件
```bash
python3 phone_segment_crawler.py --config cities_config.json
```

### 4. 自定义参数
```bash
# 设置请求延时（避免被封IP）
python3 phone_segment_crawler.py --cities 武汉 宜昌 --delay 2.0

# 单城市自定义输出文件名
python3 phone_segment_crawler.py --city 武汉 --output my_segments.csv
```

## 支持的城市列表（部分）

| 城市名 | 文件名前缀 | 示例文件名 |
|--------|------------|------------|
| 武汉   | wuhan      | wuhan_phone_segments.csv |
| 宜昌   | yichang    | yichang_phone_segments.csv |
| 襄阳   | xiangyang  | xiangyang_phone_segments.csv |
| 北京   | beijing    | beijing_phone_segments.csv |
| 上海   | shanghai   | shanghai_phone_segments.csv |
| 深圳   | shenzhen   | shenzhen_phone_segments.csv |

## 输出格式

CSV文件包含以下字段：
- 城市名
- 运营商名  
- 3位数号段
- 7位数号段

示例：
```csv
城市名,运营商名,3位数号段,7位数号段
武汉,中国移动,134,1340710
武汉,中国移动,134,1340711
武汉,中国联通,130,1301234
```

## 注意事项

1. **网络稳定性**: 爬虫会自动重试失败的请求，建议在网络稳定时运行
2. **请求频率**: 默认延时1秒，如遇到反爬虫限制可增加 `--delay` 参数
3. **数据去重**: 脚本会自动去除重复的7位号段
4. **文件覆盖**: 如果目标文件已存在，会提示是否覆盖

## 故障排除

### 常见问题
1. **SSL连接错误**: 网络不稳定，增加延时参数或稍后重试
2. **超时错误**: 增加 `--delay` 参数，降低请求频率  
3. **数据重复**: 已自动处理，无需担心

### 推荐使用方式
```bash
# 稳定的批量爬取方式
python3 phone_segment_crawler.py --cities 武汉 宜昌 襄阳 --delay 1.5
```