# OpenStack 私有云平台搭建与运维

基于 openEuler 22.03 LTS SP3 与 **OpenStack Train** 的双节点私有云实验环境，完成从裸机准备、核心组件部署到网络／云主机运维的完整实验链路。本仓库保存虚拟机配置、快照元数据、六份课程实训报告，以及据此整理的**部署手册**与**服务验证记录**。

> ⚠️ **本仓库不是开箱即用的完整环境**：虚拟磁盘镜像（约 18 GB）未纳入版本控制。克隆后无法直接开机，需按下文[环境完整性](#六环境完整性)选择「补齐镜像」或「从零重建」。

---

## 一、环境拓扑

两台 VMware Workstation 虚拟机，各配双网卡：`ens33` 接仅主机网络（管理网），`ens34` 接 NAT 网络（外部网）。

| 角色 | 主机名 | 管理网 IP | 外部网 IP | vCPU | 内存 | 磁盘 |
|---|---|---|---|---|---|---|
| 控制节点 | `controller` | 192.168.10.10 | 192.168.20.10 | 2 | 4 GB | 40 GB |
| 计算节点 | `compute` | 192.168.10.20 | 192.168.20.20 | 2 | 4 GB | 40 GB |

网络参数（实测自实训报告终端截图）：

| 参数 | 值 |
|---|---|
| 仅主机网段 | `192.168.10.0/24`，宿主侧 `192.168.10.1` |
| NAT 网段 | `192.168.20.0/24`，网关 `192.168.20.2` |
| DNS | `114.114.114.114`、`8.8.8.8` |
| 操作系统 | openEuler 22.03 LTS SP3，内核 `5.10.0-182.0.0.95.oe2203sp3.x86_64` |
| 虚拟硬件 | Workstation 17（virtualHW 21），SCSI LSILogic，e1000 网卡 |

`/etc/hosts` 两个节点保持一致：

```
192.168.10.10  controller
192.168.10.20  compute
```

> 注：该环境全部服务端点使用主机名 `controller` 而非 IP，因此 `/etc/hosts` 的域名解析是整条链路的前提。

---

## 二、部署进度与快照对照

工程按实验进度逐级打快照，形成增量磁盘链。快照名与实训报告的对应关系如下：

| 快照 | 时间 | 覆盖内容 | 对应实训 |
|---|---|---|---|
| `keystone完成` | 2026-04-28 17:14 | Keystone 认证服务 | 实训03 §1 |
| `实验三完成` | 2026-04-29 12:17 | + Glance、Placement、Nova | 实训03 全部 |
| `Neutron完成` | 2026-04-29 14:15 | + Neutron 网络服务 | 实训04 §1 |
| `虚拟网络和子网`（当前） | 2026-04-30 19:21 | + Dashboard、Cinder、Flat 网络与子网 | 实训04 §2-3、实训05 |

计算节点快照链至 `Neutron完成`。各快照对应的磁盘文件与磁盘链关系，见 `控制节点/控制节点.vmsd`、`计算节点/计算节点.vmsd`。

---

## 三、文档导航

| 文档 | 内容 |
|---|---|
| [docs/部署手册.md](docs/部署手册.md) | **实际部署步骤**：环境准备、本地软件源、Chrony／MariaDB／RabbitMQ／Memcached／etcd 基础服务、Keystone／Glance／Placement／Nova／Neutron／Dashboard／Cinder 逐组件部署，含关键配置文件与参数 |
| [docs/服务验证记录.md](docs/服务验证记录.md) | **服务验证记录**：各组件验证命令、观测结果、证据来源，以及实训中真实遇到的故障与处理 |
| [scripts/verify-openstack.sh](scripts/verify-openstack.sh) | 一键服务自检脚本，依次检查认证、计算、网络、存储服务状态 |

---

## 四、目录结构

```
.
├── README.md
├── docs/
│   ├── 部署手册.md
│   └── 服务验证记录.md
├── scripts/
│   └── verify-openstack.sh
├── .gitignore
└── OpenStack 私有云平台搭建与运维/
    ├── 云计算技术与应用_实训报告0{1..6}_...docx   # 原始课程实训报告（含终端截图）
    ├── 控制节点/
    │   ├── 控制节点.vmx      # 硬件配置
    │   ├── 控制节点.vmsd     # 快照定义
    │   ├── 控制节点.vmxf     # 扩展配置
    │   ├── 控制节点.nvram    # 虚拟 BIOS
    │   └── 控制节点-Snapshot{4..7}.vmsn
    └── 计算节点/
        ├── 计算节点.vmx
        ├── 计算节点.vmsd
        ├── 计算节点.vmxf
        ├── 计算节点.nvram
        └── 计算节点-Snapshot{4..6}.vmsn
```

六份实训报告是本文档的事实来源，逐份内容为：

| 报告 | 日期 | 主题 |
|---|---|---|
| 01 | 4月18日 | openEuler 操作系统安装（VMware 建机、双网卡、静态 IP、SSH） |
| 02 | 4月24日 | 云计算平台基础环境准备（克隆节点、本地源、Chrony／MariaDB／RabbitMQ／Memcached／etcd） |
| 03 | 5月8日 | 安装 OpenStack 组件(1)：Keystone、Glance、Placement、Nova |
| 04 | 5月15日 | 安装 OpenStack 组件(2)：Neutron、Dashboard、Cinder |
| 05 | 5月15日 | OpenStack 虚拟网络管理（Dashboard 与命令行双模式） |
| 06 | 5月22日 | 实例类型与云主机管理（含快照） |

---

## 五、软件与介质清单

部署所需介质如下（均未纳入仓库）：

| 文件 | 大小 | 用途 |
|---|---|---|
| `openEuler-22.03-LTS-SP3-x86_64-dvd.iso` | 3.5 GB | 节点操作系统安装 |
| `openStack-train.iso` | 632 MB | OpenStack Train 本地软件源 |
| `CentOS-7-x86_64-GenericCloud-2009.qcow2` | 848 MB | Glance 云主机镜像 |
| `cirros-0.5.1-x86_64-disk.img` | 16 MB | 轻量测试镜像 |
| `VMware-workstation-full-17.5.2.exe` | 618 MB | 虚拟化平台 |
| `MobaXterm_Personal_23.2.exe` | 16 MB | SSH 远程登录与文件传输 |

已部署组件版本（实测自截图）：

| 组件 | 版本 | 组件 | 版本 |
|---|---|---|---|
| openstack-keystone | 16.0.2 | openstack-nova-compute | 20.6.1 |
| openstack-cinder | 15.6.0 | httpd | 2.4.51 |
| python3-openstackclient | 4.0.2 | rabbitmq-server | 3.9.23 |
| memcached | 1.6.12 | — | — |

> 版本号取自各组件 `yum install` 与 `systemctl status` 输出。openEuler 的 `OpenStack_Train` 仓库在点版本号上与上游 Train 发布号存在差异，属正常现象。

---

## 六、环境完整性

### 为什么没有磁盘镜像

| 节点 | 磁盘链大小 |
|---|---|
| 控制节点（7 个文件） | ≈ 10.1 GB |
| 计算节点（5 个文件） | ≈ 8.0 GB |
| 合计 | ≈ 18.1 GB |

GitHub 单文件上限 100 MB、单次推送上限 2 GB，而最大单个 `.vmdk` 达 4.98 GB；虚拟磁盘属二进制大对象，每次变更产生整份新版本，也不适合 Git 管理。因此 `.gitignore` 排除了 `*.vmdk`、`*.lck/`、`*.scoreboard` 与 VMware 运行日志。

`.vmx` 中记录的当前磁盘为 `controller-000005.vmdk` / `controller-cl1-000004.vmdk`，缺失这些文件时虚拟机无法开机。

### 两条可行路径

**路径 A — 补齐镜像**：从备份介质恢复完整磁盘文件，与 `.vmx`／`.vmsd`／`.nvram`／`.vmsn` 放入同一目录，用 Workstation 17 打开即可回到任一快照。

**路径 B — 从零重建**：按 [docs/部署手册.md](docs/部署手册.md) 从 openEuler 裸机开始重装。该路径不依赖任何磁盘镜像，仅需上文介质清单，两条完整链路（建机→基础环境→核心组件→运维）均有对应步骤与验证方法。预计耗时：环境准备约 2 小时，核心组件约 4 小时。
