# 智能体 Root 指令桥 (Agent Root Bridge)

[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-brightgreen.svg)](https://kernelsu.org)
[![Magisk](https://img.shields.io/badge/Magisk-Supported-blue.svg)](https://github.com/topjohnwu/Magisk)
[![Android](https://img.shields.io/badge/Android-12%20~%2017-orange.svg)](https://android.com)

专为各类 **AI 智能体（Agent）** 设计的高安全性、高可靠性后台 Root 指令执行桥接模块。

---

## 🌟 核心设计与特性

1. **完全解耦与单一职责**：
   - 专职负责监听 `/sdcard/Download/rm_bridge/control/*.sh`，以 Root 权限静默执行命令并将结果保存到 `output/*.out`。
   - 彻底剥离一切网络端口穿透或外部业务逻辑，保持极致轻量。
2. **FUSE 挂载安全防线（防应用启动闪退）**：
   - 开机阶段双重检测：严格等待 `sys.boot_completed=1` 与 `/sdcard` 挂载就绪，杜绝在系统引导早期抢占物理目录节点导致 Android FUSE 存储死锁。
3. **全局单例防抖锁 (PID Lock)**：
   - 具备进程防抖与排他锁机制，杜绝并发执行或自嵌套派生的 Fork 炸弹。
4. **内置高危命令拦截引擎**：
   - 自动阻断 `reboot` / `poweroff` / `sys.powerctl`（保护临时 Root 手机不掉 Root）。
   - 自动阻断针对系统根目录的危险递归删除（如 `rm -rf /` 或 `/system` 等）。
5. **审计与生命周期管理**：
   - 自动按日轮转生成审计日志，自动淘汰超期结果文件，存储开销可控。

---

## 📂 模块文件结构

```text
.
├── module.prop      # 模块属性定义
├── service.sh       # 后台静默执行守护脚本
├── action.sh        # KernelSU Manager 操作交互脚本
└── customize.sh     # 模块安装与权限配置
```

---

## 📄 License
MIT License
