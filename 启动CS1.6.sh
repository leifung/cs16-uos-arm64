#!/bin/bash
# ============================================================
#  Counter-Strike 1.6 启动器（统信 UOS / Linux，原生 Xash3D，ARM64 版）
#  适用机型：鲲鹏 920 / 飞腾 / 树莓派 4 等 aarch64 设备；无需 Wine、无需联网、
#  无需编译：ARM64 引擎与游戏库已内置。
#  用法：在 UOS 终端 cd 到本目录后执行  ./启动CS1.6.sh
# ============================================================

# 包根目录（无论用什么路径启动都能正确解析）
PKG="$(cd "$(dirname "$0")" && pwd)"

# 游戏数据目录：优先用英文名 game，兼容旧版中文名 游戏本体
if   [ -d "$PKG/game" ];      then DATA="$PKG/game"
elif [ -d "$PKG/游戏本体" ];   then DATA="$PKG/游戏本体"
else
  echo "[错误] 未找到游戏数据目录（$PKG/game 或 $PKG/游戏本体）"
  exit 1
fi

ENG="$PKG/engine"   # Xash3D 引擎二进制与本机库
X11DIR="$ENG/x11-aarch64"   # 内置 aarch64 版 X11 客户端库（含 XFixes/XInput2/XRandR/Xcursor 等扩展，离线环境可能没装）

# ---------- 基本检查 ----------
if [ ! -x "$ENG/xash3d" ]; then
  echo "[错误] 未找到引擎或没有执行权限：$ENG/xash3d"
  echo "        请确认 engine/ 目录随包一起拷贝，并已执行：chmod +x 启动CS1.6.sh"
  exit 1
fi
if [ ! -d "$DATA/cstrike" ] || [ ! -d "$DATA/valve" ]; then
  echo "[错误] 游戏数据不完整：$DATA 下缺少 cstrike/ 或 valve/"
  exit 1
fi
if [ ! -f "$DATA/cstrike/dlls/cs.so" ] && [ ! -f "$DATA/cstrike/dlls/cs_arm64.so" ] && [ ! -f "$DATA/cstrike/dlls/cs_amd64.so" ]; then
  echo "[错误] 缺少 CS 服务器库 cstrike/dlls/cs.so（或 cs_arm64.so / cs_amd64.so）"
  exit 1
fi

# ---------- 关键环境变量 ----------
# 让引擎找到它自带的 .so（libxash.so / libref_gl.so / libmenu.so / SDL2 / ffmpeg 等）
# 优先用内置的 X11 客户端库（含 XFixes/XInput2/XRandR/Xcursor 等扩展，离线 UOS 往往没装，会导致 SDL 报一堆红字）
export LD_LIBRARY_PATH="$X11DIR:$ENG:$LD_LIBRARY_PATH"
# 告诉引擎游戏数据在哪（该目录需同时含 valve/ 与 cstrike/）
export XASH3D_BASEDIR="$DATA"
# Xash3D 扩展资源包（菜单/UI）
for p in "$DATA/valve/extras.pk3" "$ENG/valve/extras.pk3"; do
  [ -f "$p" ] && export XASH3D_EXTRAS_PAK1="$p" && break
done
# 避免中文路径/字体异常
export LANG="${LANG:-zh_CN.UTF-8}"
export LC_ALL="${LC_ALL:-zh_CN.UTF-8}"

# ---------- 内置 glibc 兼容桥接（解决老系统 glibc 过低问题）----------
# 你的 UOS 20 自带 glibc 约 2.28，而本引擎需要 glibc 2.34，直接运行会报
# “GLIBC_2.34' not found”。包内已附带 aarch64 版 glibc 2.35 运行时
# （engine/glibc-aarch64/），通过它自带的动态链接器启动引擎即可，
# 无需升级系统、无需联网。
# 若系统 glibc 已 ≥ 2.34（如较新的 UOS），则自动走原生方式，不启用桥接。
GLIBC_BRIDGE="$ENG/glibc-aarch64"
LOADER="$GLIBC_BRIDGE/ld-linux-aarch64.so.1"
USE_BRIDGE=0
if [ -x "$LOADER" ]; then
  SYS_GLIBC=$(/lib/aarch64-linux-gnu/libc.so.6 2>/dev/null | head -1 | grep -oE '2\.[0-9]+' | head -1)
  if [ -n "$SYS_GLIBC" ] && awk "BEGIN{exit !($SYS_GLIBC < 2.34)}"; then
    USE_BRIDGE=1
  fi
fi

# ---------- 启动 ----------
cd "$ENG"
echo "[信息] 引擎目录 : $ENG"
echo "[信息] 数据目录 : $DATA"
if [ "$USE_BRIDGE" = "1" ]; then
  echo "[信息] 检测到系统 glibc $SYS_GLIBC < 2.34，启用内置 glibc 2.35 桥接运行。"
  export LD_LIBRARY_PATH="$GLIBC_BRIDGE:$X11DIR:$ENG:$LD_LIBRARY_PATH"
  echo "[信息] 正在启动 Counter-Strike 1.6 (Xash3D, 桥接模式) ..."
  echo "[提示] 若黑屏/报错，可加参数： ./启动CS1.6.sh -soft   （强制软件渲染）"
  exec "$LOADER" --library-path "$GLIBC_BRIDGE:$X11DIR:$ENG:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu" "$ENG/xash3d" -game cstrike "$@"
else
  echo "[信息] 系统 glibc $SYS_GLIBC 满足要求，原生运行。"
  echo "[信息] 正在启动 Counter-Strike 1.6 (Xash3D) ..."
  echo "[提示] 若黑屏/报错，可加参数： ./启动CS1.6.sh -soft   （强制软件渲染）"
  exec ./xash3d -game cstrike "$@"
fi
