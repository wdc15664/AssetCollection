```directory tree
./AssetCollection
	├── AAA-Start/
	│   ├── start.sh 一键运行脚本
	├── ProcessOutputResults 脚本顺序输出目录
	├── Scripts/
	│   ├── PythonScript/ Python脚本存放目录
	│   └── ... 工具执行脚本
	├── TargetInput/
	│   ├── TargetClassification/ 资产分类存放目录
	│   └── targets.txt 资产输入文件
	└── Tools/ 工具存放目录
	    ├── Nmap/
	    └── RustScan/
	    └── Subfinder/
	    └── OneForAll/
	    └── Ehole/
```

# 安装

解压 AssertCollection

```shell
tar -xzf AssertCollection.tar.gz
```

进入 Nmap 目录 rpm 安装

```shell
cd ./AssetCollection/Tools/Nmap
rpm -ivh nmap-7.98-1.x86_64.rpm
```

其他工具已解压完成

# 运行使用

输入资产，其格式可为 IP、IP:PORT、域名:PORT、域名、URL、192.168.1.0/24、192.168.1.1-100 等

文件位置：

```shell
AssetCollection/TargetInput/targets.txt
```

一键运行：

```shell
./AAA-Start/start.sh
```

# 联动工作流

联动所使用的工具比较少，仅满足最少需求。

如需增加可扩展相关扩展工具及脚本

![image-20250930161018751](.\img\image-20250930161018751.png)