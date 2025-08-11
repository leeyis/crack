# Hashcat 快速安装指南

## 🚀 一键安装

在Ubuntu 22.04服务器上快速安装hashcat及相关工具：

```bash
# 1. 检查环境（可选）
./test_install_check.sh

# 2. 执行安装
sudo ./install_hashcat_offline.sh
```

## 📋 安装前检查清单

### ✅ 必需文件
确保以下文件在当前目录：
- `install_hashcat_offline.sh` - 安装脚本
- `hashcat-6.2.6.tar.gz` - hashcat源码
- `hashcat-utils-1.9.tar.gz` - hashcat工具集
- `6.3.0.tar.gz` - hcxtools源码

### ✅ 系统要求
- Ubuntu 22.04 LTS
- Root或sudo权限
- 至少2GB可用磁盘空间
- 2GB+ RAM (推荐)

### ✅ 编译依赖
脚本会自动安装，或手动安装：
```bash
sudo apt update
sudo apt install build-essential make gcc g++ pkg-config libssl-dev zlib1g-dev libcurl4-openssl-dev libpcap-dev
```

## 🔧 安装过程

### 第1步：环境检查
```bash
# 运行环境检查（可选但推荐）
./test_install_check.sh
```

### 第2步：执行安装
```bash
# 给脚本执行权限
chmod +x install_hashcat_offline.sh

# 运行安装脚本
sudo ./install_hashcat_offline.sh
```

### 第3步：验证安装
```bash
# 检查hashcat版本
hashcat --version

# 检查hcxtools
hcxpcapngtool --version

# 查看所有安装的工具
ls /usr/local/bin/h*
```

## 📁 安装位置

```
/opt/hashcat/          # hashcat主程序
/opt/hashcat-utils/    # hashcat工具集  
/opt/hcxtools/         # hcxtools工具
/usr/local/bin/        # 可执行文件链接
```

## 🎯 快速使用

### WiFi密码破解
```bash
# 1. 转换握手包
hcxpcapngtool -o hash.hc22000 capture.cap

# 2. 字典攻击
hashcat -m 22000 hash.hc22000 wordlist.txt

# 3. 掩码攻击（8位数字）
hashcat -m 22000 hash.hc22000 -a 3 ?d?d?d?d?d?d?d?d
```

### 常用命令
```bash
# 查看支持的hash类型
hashcat --help | grep -i wpa

# 查看GPU信息
hashcat -I

# 恢复中断的任务
hashcat --restore
```

## 🛠️ 故障排除

### 🚨 常见错误及解决方案

#### 1. libpcap依赖冲突
**错误信息**: `libpcap0.8-dev : Depends: libpcap0.8 (= 1.10.1-4build1) but 1.10.1-4ubuntu1.22.04.1 is to be installed`

**解决方案**:
```bash
# 方法1: 运行依赖修复脚本（推荐）
sudo ./fix_dependencies.sh

# 方法2: 手动解决
sudo apt remove libpcap0.8-dev
sudo apt autoremove
sudo apt install libpcap-dev
```

#### 2. APT锁定问题
**错误信息**: `Could not get lock /var/lib/dpkg/lock-frontend`

**解决方案**:
```bash
# 杀死APT进程
sudo killall apt apt-get dpkg

# 删除锁定文件
sudo rm /var/lib/dpkg/lock-frontend
sudo rm /var/lib/dpkg/lock
sudo rm /var/cache/apt/archives/lock

# 重新配置
sudo dpkg --configure -a
```

#### 3. 编译失败
**错误信息**: `make: *** [target] Error 1` 或 `No targets specified and no makefile found`

**解决方案**:
```bash
# hashcat编译问题
cd hashcat-6.2.6
make clean
make -j$(nproc)

# hashcat-utils编译问题（Makefile在src目录）
cd hashcat-utils-1.9/src
make clean
make native

# 检查依赖是否完整
sudo apt install build-essential make gcc g++
```

### 权限问题
```bash
# 确保使用sudo
sudo ./install_hashcat_offline.sh

# 检查文件权限
ls -la install_hashcat_offline.sh
```

### 网络问题
```bash
# 检查网络连接
ping -c 3 8.8.8.8

# 离线安装模式
# 确保所有依赖已预先安装
```

### 编译失败
```bash
# 清理并重新编译
cd hashcat-6.2.6
make clean
make -j$(nproc)
```

### 路径问题
```bash
# 检查PATH
echo $PATH

# 手动添加路径
export PATH="/usr/local/bin:$PATH"

# 永久添加
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 🔄 卸载方法

```bash
# 删除安装目录
sudo rm -rf /opt/hashcat /opt/hashcat-utils /opt/hcxtools

# 删除符号链接
sudo rm -f /usr/local/bin/hashcat
sudo rm -f /usr/local/bin/hcx*

# 清理其他链接
sudo find /usr/local/bin -type l -exec test ! -e {} \; -delete
```

## 📊 性能优化

### CPU优化
- 脚本自动使用所有CPU核心编译
- 多核服务器编译更快

### GPU加速
```bash
# 安装OpenCL支持
sudo apt install ocl-icd-opencl-dev

# 检查GPU
hashcat -I
```

### 内存优化
```bash
# 检查内存使用
free -h

# 大字典文件建议使用SSD存储
```

## 🔐 安全提醒

⚠️ **重要提醒**
- 仅在授权环境中使用
- 遵守当地法律法规
- 不得用于非法目的
- 定期更新工具版本

## 📞 技术支持

### 常见问题
1. **编译失败** → 检查依赖包是否完整
2. **权限错误** → 确保使用sudo运行
3. **找不到命令** → 检查PATH环境变量
4. **GPU不工作** → 安装对应的OpenCL驱动

### 日志查看
安装过程中的所有信息都会实时显示，包括：
- 彩色状态提示
- 进度条显示
- 详细错误信息

### 版本信息
- 脚本版本：v1.0
- 支持系统：Ubuntu 22.04
- hashcat版本：6.2.6
- hcxtools版本：6.3.0
- hashcat-utils版本：1.9

---

## 🎉 安装完成后

安装成功后，您将拥有一个完整的密码破解环境：

✅ hashcat - 世界最快的密码恢复工具  
✅ hcxtools - WiFi数据包处理工具  
✅ hashcat-utils - 实用工具集  
✅ 完整的命令行集成  
✅ 优化的性能配置  

**开始您的安全研究之旅！** 🔍
