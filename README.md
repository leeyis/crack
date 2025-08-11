# WPA/WPA2 智能破解工具集

一个功能强大的WPA/WPA2无线网络破解工具集，集成了从数据采集、字典生成到自动化破解的全流程，专为高效破解和安全研究而设计。

## 核心功能

本项目旨在提供一套自动化、智能化的WPA/WPA2破解流水线。它封装了强大的 `hashcat` 工具，并围绕其构建了一系列辅助脚本，特别强化了针对中国用户常见密码习惯（如手机号、生日）的字典生成和攻击策略。

无论您是安全研究人员还是渗透测试工程师，本工具集都能帮助您简化破解流程，将精力集中在策略而非繁琐的操作上。

## 主要特性

- **智能工具链检测**: 自动检测 `hashcat`, `hcxtools`, `hashcat-utils` 等核心工具的路径，无需手动配置。
- **自动化握手包转换**: 支持直接使用 `.cap` 格式的握手包文件，脚本会自动调用转换工具（如`hcxpcapngtool`）生成 `hashcat` 支持的 `.hc22000` 格式。
- **多种攻击模式**:
    - **自动模式**: 从易到难，依次执行所有内置的攻击策略。
    - **快速模式**: 仅执行最高效的攻击，如常见弱口令、高频生日等。
    - **生日模式**: 专门针对 `YYYYMMDD` 格式的生日密码进行深度破解。
    - **字典模式**: 支持使用自定义字典文件进行攻击。
    - **自定义模式**: 灵活组合多种内置的掩码攻击策略。
- **实时破解进度监控**: 提供美观、实时的进度条，动态显示破解速度、已尝试密码量、预计剩余时间（ETA）等关键信息。
- **高效字典生成器**: 内置脚本，可快速生成大规模、有针对性的字典文件。
    - **手机号字典**: 可爬取指定城市的手机号段，并生成完整的11位手机号码字典。
    - **内置小字典**: 脚本内置了常见弱口令、百家姓、高频生日等多种小型字典，无需外部下载。

## 项目结构

```
.
├── crack.sh                    # 核心智能破解脚本
├── phone_segment_crawler.py    # 手机号段爬虫 (Python)
├── gen_phone_dic.sh            # 手机号字典生成脚本
├── requirements.txt            # Python环境依赖
├── install_hashcat_offline.sh  # 核心工具离线安装脚本
├── dic_file/                   # 存放字典文件的目录
└── handshake_22000.hc22000     # 示例用握手包文件
```

- **`crack.sh`**: 项目的入口和总调度器。
- **`phone_segment_crawler.py`**: 数据来源，用于生成手机号字典的第一步。
- **`gen_phone_dic.sh`**: 字典生成工具，将号段数据转化为可用的字典文件。

## 安装与环境配置

### 1. Python 环境

本项目的爬虫脚本使用 Python 编写。请先确保您已安装 Python 3。

```bash
# 安装Python依赖
pip install -r requirements.txt
```

### 2. 核心工具

本项目依赖 `hashcat` (破解核心) 和 `hcxtools` (握手包处理)。

**在线安装 (推荐)**:
```bash
# 对于 Debian/Ubuntu 系统
sudo apt update
sudo apt install hashcat hcxtools -y
```

**离线安装**:
如果您在无法访问互联网的环境中，可以使用项目提供的离线安装包和脚本。

1.  确保 `hashcat-6.2.6.tar.gz`, `hashcat-utils-1.9.tar.gz`, `hcxtools-6.3.0.tar.gz` 文件位于项目根目录。
2.  执行离线安装脚本：
    ```bash
    chmod +x install_hashcat_offline.sh
    ./install_hashcat_offline.sh
    ```
该脚本会自动解压、编译和安装所有核心工具。

## 使用方法

### 步骤 1: 准备字典 (可选)

如果您怀疑密码与特定地区的手机号相关，可以生成一个定制化的手机号字典。

**a. 爬取手机号段**

使用 `phone_segment_crawler.py` 爬取一个或多个城市的手机号段。

```bash
# 爬取单个城市 (例如：武汉)
python3 phone_segment_crawler.py --city "武汉"

# 爬取多个城市
python3 phone_segment_crawler.py --cities "武汉" "宜昌" "襄阳"

# 使用配置文件批量爬取
python3 phone_segment_crawler.py --config "cities_config.json"
```
爬取完成后，会生成对应城市的CSV文件，如 `wuhan_phone_segments.csv`。

**b. 生成手机号字典**

使用 `gen_phone_dic.sh` 将上一步生成的CSV文件转换为完整的11位手机号码字典。

```bash
# 为武汉市生成手机号字典
chmod +x gen_phone_dic.sh
./gen_phone_dic.sh wuhan_phone_segments.csv
```
执行后，会生成一个名为 `wuhan.txt` 的字典文件，其中包含该城市所有的手机号码。

### 步骤 2: 执行破解

使用 `crack.sh` 启动破解程序。

**基本用法**

```bash
chmod +x crack.sh
./crack.sh [握手包文件] [可选参数]
```

- **握手包文件**: 支持 `.cap`, `.pcap`, `.hc22000` 格式。如果是 `.cap` 文件，脚本会自动进行转换。
- **可选参数**:
    - `-w <1-4>`: 设置 `hashcat` 的工作负载强度 (1:低, 2:中, 3:高, 4:疯狂)。
    - `--debug`: 启用调试模式，输出更详细的信息。

**示例**

```bash
# 启动交互式菜单，并指定握手包
./crack.sh my_handshake.cap

# 直接破解，并设置中等负载强度
./crack.sh my_handshake.cap -w 2
```

**交互式菜单**

如果不带任何攻击模式参数运行，脚本会显示一个菜单，让您选择攻击模式：

```
请选择破解模式：
[1] 自动模式 - 按难度从易到难依次执行所有攻击
[2] 快速模式 - 仅执行高效攻击(字典+常见密码)
[3] 生日模式 - 专门破解生日相关密码
[4] 自定义模式 - 手动选择要执行的攻击类型
[5] 字典模式 - 选择字典文件进行攻击
[0] 退出程序
```

- 选择 **[5] 字典模式**，可以进一步选择脚本内置的小字典或您自己生成的字典文件（如 `wuhan.txt`）。

## 完整工作流示例

**场景**: 捕获了一个名为 "TP-LINK_Wuhan" 的WIFI热点的握手包 `wuhan.cap`，怀疑其密码是武汉地区的手机号码。

**步骤**:

1.  **爬取武汉市手机号段**:
    ```bash
    python3 phone_segment_crawler.py --city "武汉"
    ```
    *这会生成 `wuhan_phone_segments.csv` 文件。*

2.  **生成武汉市手机号码字典**:
    ```bash
    ./gen_phone_dic.sh wuhan_phone_segments.csv
    ```
    *这会生成 `wuhan.txt` 字典文件。*

3.  **启动破解脚本**:
    ```bash
    ./crack.sh wuhan.cap
    ```

4.  **在交互菜单中选择攻击**:
    - 在主菜单选择 **[5] 字典模式**。
    - 在字典选择菜单中，选择您刚刚生成的 `wuhan.txt` 文件。

5.  **等待破解结果**:
    脚本将开始使用 `wuhan.txt` 字典进行破解，并实时显示进度。