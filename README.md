# 手机号段爬虫使用说明

## 功能描述
这是一个可配置的手机号段爬虫工具，可以从 https://telphone.cn 网站爬取指定城市的手机号段信息，并输出为CSV格式。

## 功能特点
- 支持单个城市或批量城市处理
- 自动识别运营商信息（中国移动、中国联通、中国电信）
- 输出CSV格式，包含城市名、运营商名、3位数号段、7位数号段
- 支持可配置的请求延时
- 支持配置文件批量处理

## 安装依赖

```bash
# 激活conda环境
conda activate dic

# 安装依赖（已安装可跳过）
pip install requests beautifulsoup4
```

## 使用方法

### 1. 单个城市爬取

```bash
# 基本用法
python phone_segment_crawler.py --city "武汉" --output "wuhan_segments.csv"

# 指定城市URL编码（如果城市名与URL编码不同）
python phone_segment_crawler.py --city "武汉" --city-url "武汉" --output "wuhan_segments.csv"

# 设置请求延时（默认1秒）
python phone_segment_crawler.py --city "武汉" --delay 2.0 --output "wuhan_segments.csv"
```

### 2. 批量城市爬取

```bash
# 使用配置文件
python phone_segment_crawler.py --config "cities_config.json" --output "all_cities_segments.csv"
```

### 3. 配置文件格式

创建 `cities_config.json` 文件：

```json
{
    "cities": [
        {
            "name": "武汉",
            "url_encoded": "武汉"
        },
        {
            "name": "北京", 
            "url_encoded": "北京"
        },
        {
            "name": "上海",
            "url_encoded": "上海"
        }
    ]
}
```

## 输出格式

生成的CSV文件包含以下列：

| 城市名 | 运营商名 | 3位数号段 | 7位数号段 |
|--------|----------|-----------|-----------|
| 武汉   | 中国移动 | 134       | 1340710   |
| 武汉   | 中国移动 | 134       | 1340711   |
| ...    | ...      | ...       | ...       |

## 参数说明

- `--city`: 城市名称（中文）
- `--city-url`: 城市的URL编码（可选，如果与城市名不同时使用）
- `--config`: 配置文件路径（用于批量处理）
- `--output`: 输出CSV文件名（默认：phone_segments.csv）
- `--delay`: 请求间隔时间，单位秒（默认：1.0）

## 注意事项

1. 请求过于频繁可能被网站限制，建议适当设置延时
2. 网络不稳定可能导致部分数据获取失败
3. 运营商信息从号段页面的标题和内容中自动识别
4. 建议在网络稳定的环境下运行

## 示例输出

```
开始爬取 武汉 号段信息...
URL: https://telphone.cn/area/%E6%AD%A6%E6%B1%89/
找到 52 个号段
正在处理号段: 134
  运营商: 中国移动, 找到 113 个7位数号段
正在处理号段: 135
  运营商: 中国移动, 找到 129 个7位数号段
...
数据已保存到 wuhan_segments.csv，共 3866 条记录
```