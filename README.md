# CS 1.6 · 统信 UOS ARM64 原生版（鲲鹏 920 适用）

无需 Wine、无需联网、无需安装任何依赖 —— 解压即玩的 **Counter-Strike 1.6** 原生 Linux（aarch64）离线包。

基于 **Xash3D FWGS** 开源引擎 + cs16-client（`client.so` / `cs.so` / `menu.so` 由 Zig 交叉编译为 aarch64）+ 原版游戏数据。

## 下载

到 [Releases](../../releases) 下载 `CS1.6-UOS-ARM64.tar.gz`（约 255 MB）。

## 适用环境

| 项目 | 要求 |
|---|---|
| CPU | aarch64（鲲鹏 920 / 飞腾 / 树莓派 4 等） |
| 系统 | 统信 UOS 20 / deepin 20 及以上（glibc ≥ 2.19 即可，低版本自动桥接） |
| 桌面 | X11 图形会话 |

## 三步上手

```bash
tar -xzf CS1.6-UOS-ARM64.tar.gz
cd CS1.6-UOS-ARM64
./启动CS1.6.sh
```

如果解压后提示无执行权限，先跑一次：

```bash
chmod +x 启动CS1.6.sh 修复CS1.6.sh 诊断CS1.6.sh
bash 修复CS1.6.sh
./启动CS1.6.sh
```

## 目录结构

```
CS1.6-UOS-ARM64/
├── 启动CS1.6.sh            # 一键启动（自动 glibc 桥接 + X11 库注入）
├── 诊断CS1.6.sh            # 出问题时跑它，生成诊断报告
├── 修复CS1.6.sh            # 兜底：补权限/补文件/清残留
├── 部署说明.md             # 详细说明与常见问题
├── engine/                 # ARM64 原生 Xash3D 引擎
│   ├── glibc-aarch64/      #   内置 glibc 2.35 运行时（老系统桥接用）
│   └── x11-aarch64/        #   内置 X11 客户端库（离线缺库兜底）
└── game/                   # 游戏数据（valve/ + cstrike/）
```

## 技术要点（为什么这个包能在老 UOS 上跑）

1. **架构匹配**：引擎与所有 `.so` 均为 aarch64（`e_machine=0xB7`），客户端库由 `zig cc/c++ -target aarch64-linux-gnu.2.34` 交叉编译。
2. **glibc 桥接**：UOS 20 自带 glibc 约 2.28，而引擎按 2.34 链接。启动脚本检测到旧 glibc 时，自动用包内置的 aarch64 版 glibc 2.35 加载器（`ld-linux-aarch64.so.1 --library-path ...`）桥接启动，**不改系统任何文件**。
3. **内置 X11 库**：精简离线系统常缺 XFixes/XInput2/XRandR 等扩展库，包内自带一套（Ubuntu 22.04 arm64 提取），经 `LD_LIBRARY_PATH` 优先加载。
4. **64 位 string_t 兼容**：FWGS 引擎在 64 位下保持 32 位 `string_t` 字符串偏移（内部字符串池设计），cs.so 已按此 ABI 修复。

## 已知限制

- **不含机器人（BOT）**：单机打电脑暂不可用；局域网/互联网联机（`connect IP:端口`）正常。
- **不含 ffmpeg**：游戏内 BINK/AVI 过场动画不播放，不影响对战与声音。

## 常见问题

| 现象 | 处理 |
|---|---|
| 启动即报 `GLIBC_2.34' not found` | 跑 `bash 修复CS1.6.sh` 后用 `./启动CS1.6.sh`，会自动桥接 |
| 大量 SDL `Failed loading X...` 红字 | 本包已内置 X11 库，理应消失；若仍出现跑 `bash 修复CS1.6.sh` |
| 黑屏但进程在跑 | 先试 `./启动CS1.6.sh -soft`；再不行 `LIBGL_ALWAYS_SOFTWARE=1 ./启动CS1.6.sh` |
| 报 `filesystem_stdio.so` 找不到 | 跑 `bash 修复CS1.6.sh`（会自动从 engine/ 补拷到 game/） |
| 仍然异常 | 跑 `bash 诊断CS1.6.sh`，把生成的报告文件发给我 |

## 许可与致谢

- 引擎：[Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs)（LGPL-3.0）
- 游戏库：[cs16-client](https://github.com/FWGS/cs16-client) / [ReGameDLL-CS](https://github.com/reHDD/ReGameDLL_CS) / [mainui_cpp](https://github.com/FWGS/mainui_cpp)
- 本仓库仅含启动脚本与打包流程说明；游戏数据请自备正版。
