#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import requests
from bs4 import BeautifulSoup
import re
import time
import os

def get_page_content(url, retry_count=3):
    """获取网页内容"""
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    for i in range(retry_count):
        try:
            response = requests.get(url, headers=headers, timeout=10)
            response.encoding = 'utf-8'
            if response.status_code == 200:
                return response.text
            else:
                print(f"请求失败，状态码: {response.status_code}")
        except Exception as e:
            print(f"请求出错 (尝试 {i+1}/{retry_count}): {e}")
            if i < retry_count - 1:
                time.sleep(2)
    
    return None

def extract_three_digit_segments(html_content):
    """从主页面提取3位数号段"""
    soup = BeautifulSoup(html_content, 'html.parser')
    segments = []
    
    # 查找包含号段的链接
    links = soup.find_all('a', href=True)
    
    for link in links:
        href = link.get('href', '')
        text = link.get_text().strip()
        
        # 匹配格式为 /prefix/武汉XXX/ 的链接，其中XXX是3位数字
        if '/prefix/武汉' in href and href.endswith('/'):
            # 从href中提取3位数字
            match = re.search(r'/prefix/武汉(\d{3})/', href)
            if match:
                segments.append(match.group(1))
    
    return list(set(segments))  # 去重

def extract_seven_digit_segments(html_content):
    """从号段子页面提取7位数号段"""
    soup = BeautifulSoup(html_content, 'html.parser')
    segments = []
    
    # 查找包含号段的链接
    links = soup.find_all('a', href=True)
    
    for link in links:
        href = link.get('href', '')
        
        # 匹配格式为 /prefix/XXXXXXX/ 的链接，其中XXXXXXX是7位数字
        if '/prefix/' in href and href.endswith('/'):
            # 从href中提取数字部分
            match = re.search(r'/prefix/(\d{7})/', href)
            if match:
                segments.append(match.group(1))
    
    return list(set(segments))  # 去重

def main():
    base_url = "https://telphone.cn/area/武汉/"
    output_file = "wuhan_phone_segments.txt"
    
    print("开始爬取武汉号段信息...")
    
    # 1. 获取主页面内容
    print("正在获取主页面...")
    main_page_content = get_page_content(base_url)
    
    if not main_page_content:
        print("无法获取主页面内容，程序退出")
        return
    
    # 2. 提取3位数号段
    print("正在提取3位数号段...")
    three_digit_segments = extract_three_digit_segments(main_page_content)
    print(f"找到 {len(three_digit_segments)} 个3位数号段: {three_digit_segments}")
    
    # 3. 遍历每个3位数号段，获取7位数号段
    all_seven_digit_segments = []
    
    for segment in three_digit_segments:
        print(f"正在处理号段: {segment}")
        segment_url = f"https://telphone.cn/prefix/武汉{segment}/"
        
        segment_content = get_page_content(segment_url)
        if segment_content:
            seven_digit_segments = extract_seven_digit_segments(segment_content)
            print(f"  找到 {len(seven_digit_segments)} 个7位数号段")
            all_seven_digit_segments.extend(seven_digit_segments)
        else:
            print(f"  无法获取号段 {segment} 的内容")
        
        # 添加延时避免请求过快
        time.sleep(1)
    
    # 4. 去重并排序
    all_seven_digit_segments = list(set(all_seven_digit_segments))
    all_seven_digit_segments.sort()
    
    # 5. 写入文件
    print(f"总共找到 {len(all_seven_digit_segments)} 个7位数号段")
    with open(output_file, 'w', encoding='utf-8') as f:
        for segment in all_seven_digit_segments:
            f.write(segment + '\n')
    
    print(f"结果已保存到 {output_file}")

if __name__ == "__main__":
    main()