# OpenStack 私有云平台搭建与运维

基于 openEuler 的 OpenStack 私有云实验环境，由 VMware Workstation 上的两台虚拟机组成，用于完成 Keystone、Neutron、Cinder 等组件的部署与运维实验。

> 本仓库只保存**虚拟机配置与快照元数据**，不含磁盘镜像（约 18 GB，超出 GitHub 限制）。详见[磁盘镜像说明](#磁盘镜像说明)。

## 目录结构

```
.
├── README.md
├── .gitignore
└── OpenStack 私有云平台搭建与运维/
    ├── 控制节点/          # controller：控制节点
    │   ├── 控制节点.vmx     # 虚拟机硬件配置
    │   ├── 控制节点.vmsd    # 快照定义
    │   ├── 控制节点.vmxf    # 扩展配置
    │   ├── 控制节点.nvram   # 虚拟 BIOS 设置
    │   └── 控制节点-Snapshot{4..7}.vmsn   # 各快照状态元数据
    └── 计算节点/          # compute：计算节点
        ├── 计算节点.vmx
        ├── 计算节点.vmsd
        ├── 计算节点.vmxf
        ├── 计算节点.nvram
        └── 计算节点-Snapshot{4..6}.vmsn
```

## 虚拟机规格

| 项目 | 控制节点 | 计算节点 |
|---|---|---|
| 角色 | Controller | Compute |
| 虚拟机标识 | `controller` | `controller-cl1` |
| 客户机系统 | openEuler 22.03 LTS SP3 (x86_64) | 同左 |
| vCPU | 2 | 2 |
| 内存 | 4 GB | 4 GB |
| 磁盘控制器 | SCSI (LSILogic) | SCSI (LSILogic) |
| 网卡 0 | Host-only（管理网） | Host-only（管理网） |
| 网卡 1 | NAT（外网出口） | NAT（外网出口） |
| 虚拟硬件版本 | 21 (Workstation 17.x) | 21 (Workstation 17.x) |

安装介质：`openEuler-22.03-LTS-SP3-x86_64-dvd.iso`（已挂载为 CD-ROM，ISO 本身未纳入仓库）。

## 快照链

两台虚拟机按实验进度逐级打快照，形成增量磁盘链。

### 控制节点

| 顺序 | 快照名 | 时间 | 该快照对应磁盘 |
|---|---|---|---|
| 1 | keystone完成 | 2026-04-28 17:14 | `controller.vmdk` |
| 2 | 实验三完成 | 2026-04-29 12:17 | `controller-000003.vmdk` |
| 3 | Neutron完成 | 2026-04-29 14:15 | `controller-000001.vmdk` |
| 4 | 虚拟网络和子网（当前） | 2026-04-30 19:21 | `controller-000004.vmdk` + `cinder.vmdk` |

当前运行状态磁盘：`controller-000005.vmdk`（快照 4 之后的增量）。

### 计算节点

| 顺序 | 快照名 | 时间 | 该快照对应磁盘 |
|---|---|---|---|
| 1 | keystone完成 | 2026-04-28 17:14 | `controller-cl1.vmdk` |
| 2 | 实验三完成 | 2026-04-29 12:17 | `controller-cl1-000003.vmdk` |
| 3 | Neutron完成（当前） | 2026-04-29 14:15 | `controller-cl1-000001.vmdk` |

当前运行状态磁盘：`controller-cl1-000004.vmdk`。

控制节点在第 4 个快照时新增了第二块磁盘 `cinder.vmdk`（挂载于 `scsi0:1`），用于 Cinder 块存储实验。

## 磁盘镜像说明

| | 大小 |
|---|---|
| 控制节点磁盘链（7 个文件） | ≈ 10.1 GB |
| 计算节点磁盘链（5 个文件） | ≈ 8.0 GB |
| 合计 | ≈ 18.1 GB |

未纳入仓库的原因：

- GitHub 单文件上限 **100 MB**，单次推送上限 **2 GB**，而本环境单个 `.vmdk` 最大 **4.98 GB**；
- 虚拟磁盘属于二进制大对象，每次改动都会产生整份新版本，不适合用 Git 管理。

因此 `.gitignore` 排除了 `*.vmdk`、`*.lck/`、`*.scoreboard` 和 VMware 运行日志。

> ⚠️ **注意**：`.vmx` 中记录的当前磁盘是 `controller-000005.vmdk` / `controller-cl1-000004.vmdk`。直接克隆本仓库后双击 `.vmx` 会因缺少磁盘文件而无法开机，需先补齐磁盘镜像。

## 如何复用本环境

1. 准备 `openEuler-22.03-LTS-SP3-x86_64-dvd.iso`。
2. 将本仓库中对应节点的 `.vmx`、`.vmsd`、`.nvram`、`.vmsn` 与磁盘镜像放入同一目录。
3. 用 VMware Workstation 17 及以上版本打开 `.vmx`。
4. 按需在快照管理器中回滚到 `keystone完成` / `实验三完成` / `Neutron完成` 等节点继续实验。
