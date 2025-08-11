#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
通用手机号段爬虫
支持配置城市URL，爬取指定城市的手机号段信息并输出CSV格式
"""

import requests
from bs4 import BeautifulSoup
import re
import time
import csv
import json
import argparse
from urllib.parse import quote
from typing import List, Dict, Tuple

class PhoneSegmentCrawler:
    def __init__(self, delay=1):
        """
        初始化爬虫
        :param delay: 请求间隔时间（秒）
        """
        self.delay = delay
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
        
    def get_page_content(self, url: str, retry_count: int = 5) -> str:
        """获取网页内容，增强重试机制"""
        for i in range(retry_count):
            try:
                # 增加更长的超时时间
                response = self.session.get(url, timeout=30)
                response.encoding = 'utf-8'
                if response.status_code == 200:
                    return response.text
                else:
                    print(f"请求失败，状态码: {response.status_code}, URL: {url}")
            except Exception as e:
                print(f"请求出错 (尝试 {i+1}/{retry_count}): {e}, URL: {url}")
                if i < retry_count - 1:
                    # 递增等待时间
                    wait_time = 2 * (i + 1)
                    print(f"等待 {wait_time} 秒后重试...")
                    time.sleep(wait_time)
        
        return None
    
    def extract_segments_info(self, html_content: str) -> List[Tuple[str, str]]:
        """
        从城市主页面提取运营商和3位数号段信息
        返回: [(运营商名, 3位数号段), ...]
        """
        soup = BeautifulSoup(html_content, 'html.parser')
        segments_info = []
        segment_set = set()  # 用于去重
        
        # 查找所有list-box div（每个运营商一个）
        list_boxes = soup.find_all('div', class_='list-box')
        
        for list_box in list_boxes:
            # 查找运营商名称
            title_div = list_box.find('div', class_='title')
            if title_div:
                operator = title_div.get_text().strip()
                
                # 查找该运营商下的所有号段链接
                ul = list_box.find('ul')
                if ul:
                    links = ul.find_all('a', href=True)
                    
                    for link in links:
                        href = link.get('href', '')
                        
                        # 匹配格式为 /prefix/城市XXX/ 的链接，其中XXX是3位数字
                        if '/prefix/' in href and href.endswith('/'):
                            # 从href中提取3位数字
                            match = re.search(r'/prefix/[^/]*?(\d{3})/', href)
                            if match:
                                segment = match.group(1)
                                # 使用set进行去重
                                segment_key = (operator, segment)
                                if segment_key not in segment_set:
                                    segment_set.add(segment_key)
                                    segments_info.append((operator, segment))
                                else:
                                    print(f"发现重复3位号段，已去除: {operator} - {segment}")
        
        print(f"3位号段去重: 原始数量可能更多，去重后: {len(segments_info)} 个")
        return segments_info
    
    def get_operator_from_segment_page(self, city_url_encoded: str, segment: str) -> str:
        """
        通过访问号段子页面获取运营商信息
        """
        segment_url = f"https://telphone.cn/prefix/{city_url_encoded}{segment}/"
        content = self.get_page_content(segment_url)
        
        if content:
            soup = BeautifulSoup(content, 'html.parser')
            
            # 从页面标题中获取运营商信息
            title = soup.find('title')
            if title:
                title_text = title.get_text()
                
                if '中国移动' in title_text or '移动' in title_text:
                    return '中国移动'
                elif '中国联通' in title_text or '联通' in title_text:
                    return '中国联通'
                elif '中国电信' in title_text or '电信' in title_text:
                    return '中国电信'
            
            # 如果标题中没有找到，从页面内容中查找
            page_text = soup.get_text()
            if '中国移动' in page_text:
                return '中国移动'
            elif '移动' in page_text and ('GSM' in page_text or 'TD-SCDMA' in page_text or 'TD-LTE' in page_text):
                return '中国移动'
            elif '中国联通' in page_text:
                return '中国联通'
            elif '联通' in page_text and ('GSM' in page_text or 'WCDMA' in page_text or 'FDD-LTE' in page_text):
                return '中国联通'
            elif '中国电信' in page_text:
                return '中国电信'
            elif '电信' in page_text and ('CDMA' in page_text or 'FDD-LTE' in page_text):
                return '中国电信'
        
        return '未知运营商'
    
    def extract_operator_from_page(self, html_content: str) -> str:
        """
        从页面内容中提取运营商信息
        """
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # 从页面标题中获取运营商信息
        title = soup.find('title')
        if title:
            title_text = title.get_text()
            
            if '中国移动' in title_text or '移动' in title_text:
                return '中国移动'
            elif '中国联通' in title_text or '联通' in title_text:
                return '中国联通'
            elif '中国电信' in title_text or '电信' in title_text:
                return '中国电信'
        
        # 如果标题中没有找到，从页面内容中查找
        page_text = soup.get_text()
        if '中国移动' in page_text:
            return '中国移动'
        elif '移动' in page_text and ('GSM' in page_text or 'TD-SCDMA' in page_text or 'TD-LTE' in page_text):
            return '中国移动'
        elif '中国联通' in page_text:
            return '中国联通'
        elif '联通' in page_text and ('GSM' in page_text or 'WCDMA' in page_text or 'FDD-LTE' in page_text):
            return '中国联通'
        elif '中国电信' in page_text:
            return '中国电信'
        elif '电信' in page_text and ('CDMA' in page_text or 'FDD-LTE' in page_text):
            return '中国电信'
        
        return '未知运营商'
    
    def extract_seven_digit_segments(self, html_content: str) -> List[str]:
        """从号段子页面提取7位数号段"""
        soup = BeautifulSoup(html_content, 'html.parser')
        segments = []
        
        # 查找包含号段的链接
        links = soup.find_all('a', href=True)
        
        for link in links:
            href = link.get('href', '')
            
            # 匹配格式为 /prefix/XXXXXXX/ 的链接，其中XXXXXXX是7位数字
            if '/prefix/' in href and href.endswith('/'):
                match = re.search(r'/prefix/(\d{7})/', href)
                if match:
                    segments.append(match.group(1))
        
        return list(set(segments))  # 去重
    
    def crawl_city_segments(self, city_name: str, city_url_encoded: str = None) -> List[Dict]:
        """
        爬取指定城市的手机号段信息
        :param city_name: 城市名称
        :param city_url_encoded: 城市的URL编码（如果为None则使用city_name）
        :return: 包含所有号段信息的列表
        """
        if city_url_encoded is None:
            city_url_encoded = quote(city_name)
        
        base_url = f"https://telphone.cn/area/{city_url_encoded}/"
        print(f"开始爬取 {city_name} 号段信息...")
        print(f"URL: {base_url}")
        
        # 1. 获取城市主页面内容
        main_page_content = self.get_page_content(base_url)
        if not main_page_content:
            print(f"无法获取 {city_name} 主页面内容")
            return []
        
        # 2. 提取3位数号段信息和运营商信息
        segments_info = self.extract_segments_info(main_page_content)
        print(f"找到 {len(segments_info)} 个号段")
        
        # 3. 爬取每个3位数号段的7位数子号段
        all_data = []
        
        for operator, three_digit_segment in segments_info:
            print(f"正在处理号段: {three_digit_segment} ({operator})")
            
            # 构建子页面URL
            segment_url = f"https://telphone.cn/prefix/{city_url_encoded}{three_digit_segment}/"
            
            segment_content = self.get_page_content(segment_url)
            if segment_content:
                # 从子页面内容中获取7位数号段
                seven_digit_segments = self.extract_seven_digit_segments(segment_content)
                print(f"  运营商: {operator}, 找到 {len(seven_digit_segments)} 个7位数号段")
                
                # 将数据添加到结果列表
                for seven_digit_segment in seven_digit_segments:
                    all_data.append({
                        '城市名': city_name,
                        '运营商名': operator,
                        '3位数号段': three_digit_segment,
                        '7位数号段': seven_digit_segment
                    })
            else:
                print(f"  无法获取号段 {three_digit_segment} 的内容")
            
            # 添加延时避免请求过快
            time.sleep(self.delay)
        
        return all_data
    
    def save_to_csv(self, data: List[Dict], filename: str):
        """将数据保存为CSV文件"""
        if not data:
            print("没有数据可保存")
            return
        
        # 进一步去重：基于7位数号段进行去重
        unique_data = []
        seen_segments = set()
        
        for item in data:
            segment_key = item['7位数号段']
            if segment_key not in seen_segments:
                seen_segments.add(segment_key)
                unique_data.append(item)
            else:
                print(f"发现重复7位号段，已去除: {segment_key}")
        
        print(f"去重前: {len(data)} 条记录，去重后: {len(unique_data)} 条记录")
        
        fieldnames = ['城市名', '运营商名', '3位数号段', '7位数号段']
        
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(unique_data)
        
        print(f"数据已保存到 {filename}，共 {len(unique_data)} 条记录")

def load_config(config_file: str) -> Dict:
    """加载配置文件"""
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"配置文件 {config_file} 不存在")
        return {}
    except json.JSONDecodeError as e:
        print(f"配置文件格式错误: {e}")
        return {}

def get_city_pinyin(city_name: str) -> str:
    """城市汉字到拼音的映射函数"""
    city_mapping = {
        "北京": "beijing",
        "上海": "shanghai", 
        "天津": "tianjin",
        "重庆": "chongqing",
        "广州": "guangzhou",
        "深圳": "shenzhen",
        "武汉": "wuhan",
        "南京": "nanjing",
        "杭州": "hangzhou",
        "成都": "chengdu",
        "西安": "xian",
        "苏州": "suzhou",
        "青岛": "qingdao",
        "大连": "dalian",
        "宁波": "ningbo",
        "厦门": "xiamen",
        "福州": "fuzhou",
        "昆明": "kunming",
        "沈阳": "shenyang",
        "长春": "changchun",
        "哈尔滨": "haerbin",
        "石家庄": "shijiazhuang",
        "太原": "taiyuan",
        "呼和浩特": "huhehaote",
        "郑州": "zhengzhou",
        "济南": "jinan",
        "合肥": "hefei",
        "南昌": "nanchang",
        "长沙": "changsha",
        "海口": "haikou",
        "三亚": "sanya",
        "南宁": "nanning",
        "贵阳": "guiyang",
        "拉萨": "lasa",
        "兰州": "lanzhou",
        "西宁": "xining",
        "银川": "yinchuan",
        "乌鲁木齐": "wulumuqi",
        "台北": "taibei",
        "香港": "xianggang",
        "澳门": "aomen",
        "宜昌": "yichang",
        "襄阳": "xiangyang",
        "十堰": "shiyan",
        "荆州": "jingzhou",
        "黄冈": "huanggang",
        "孝感": "xiaogan",
        "荆门": "jingmen",
        "鄂州": "ezhou",
        "黄石": "huangshi",
        "咸宁": "xianning",
        "随州": "suizhou",
        "恩施": "enshi"
    }
    
    return city_mapping.get(city_name, city_name.lower())

def main():
    parser = argparse.ArgumentParser(description='手机号段爬虫')
    parser.add_argument('--cities', type=str, nargs='+', help='城市名称列表（如：武汉 宜昌 襄阳）')
    parser.add_argument('--city', type=str, help='单个城市名称（如：武汉）')
    parser.add_argument('--city-url', type=str, help='城市URL编码（如果与城市名称不同）')
    parser.add_argument('--config', type=str, help='配置文件路径')
    parser.add_argument('--output', type=str, help='输出CSV文件名（单城市时使用）')
    parser.add_argument('--delay', type=float, default=1.0, help='请求间隔时间（秒）')
    
    args = parser.parse_args()
    
    crawler = PhoneSegmentCrawler(delay=args.delay)
    
    if args.cities:
        # 多个城市，为每个城市生成单独的CSV文件
        for city_name in args.cities:
            print(f"\n{'='*50}")
            print(f"开始处理城市: {city_name}")
            print(f"{'='*50}")
            
            city_pinyin = get_city_pinyin(city_name)
            output_filename = f"{city_pinyin}_phone_segments.csv"
            
            data = crawler.crawl_city_segments(city_name)
            if data:
                crawler.save_to_csv(data, output_filename)
            else:
                print(f"城市 {city_name} 没有获取到任何数据")
    
    elif args.config:
        # 从配置文件加载城市列表
        config = load_config(args.config)
        cities = config.get('cities', [])
        
        for city_config in cities:
            city_name = city_config.get('name')
            city_url_encoded = city_config.get('url_encoded')
            
            if city_name:
                print(f"\n{'='*50}")
                print(f"开始处理城市: {city_name}")
                print(f"{'='*50}")
                
                city_pinyin = get_city_pinyin(city_name)
                output_filename = f"{city_pinyin}_phone_segments.csv"
                
                data = crawler.crawl_city_segments(city_name, city_url_encoded)
                if data:
                    crawler.save_to_csv(data, output_filename)
                else:
                    print(f"城市 {city_name} 没有获取到任何数据")
    
    elif args.city:
        # 单个城市
        output_filename = args.output if args.output else f"{get_city_pinyin(args.city)}_phone_segments.csv"
        data = crawler.crawl_city_segments(args.city, args.city_url)
        if data:
            crawler.save_to_csv(data, output_filename)
        else:
            print("没有获取到任何数据")
    
    else:
        print("请指定城市名称:")
        print("  单个城市: --city 武汉")
        print("  多个城市: --cities 武汉 宜昌 襄阳")
        print("  配置文件: --config cities_config.json")
        return

if __name__ == "__main__":
    main()