#!/bin/bash
# ============================================================
#  CS 1.6 (Xash3D) 在 UOS / Linux 上的「错误收集脚本」
#  用途：一键收集系统/架构/库依赖/启动报错，生成 CS1.6诊断报告.txt
#  用法：把本脚本放进 CS1.6-UOS-Xash3D 目录，在 UOS 图形桌面的终端里执行：
#          bash 诊断CS1.6.sh
#  然后把生成的 CS1.6诊断报告.txt 发回即可。
# ============================================================

PKG="$(cd "$(dirname "$0")" && pwd)"
REPORT="$PKG/CS1.6诊断报告.txt"

# 自动找游戏数据目录
if   [ -d "$PKG/game" ];     then DATA="$PKG/game"
elif [ -d "$PKG/游戏本体" ];  then DATA="$PKG/游戏本体"
else DATA=""; fi

{
echo "############## CS 1.6 Xash3D 诊断报告 ##############"
echo "生成时间 : $(date)"
echo "脚本目录 : $PKG"
echo ""

echo "===== 1. 系统 / 架构（最关键）====="
echo "uname -a : $(uname -a)"
echo "uname -m : $(uname -m)   <-- 若为 aarch64/armv7l 表示 ARM；loongarch 表示龙芯；x86_64 才是 amd64"
echo "--- /etc/os-release ---"
[ -r /etc/os-release ] && cat /etc/os-release
echo "--- 桌面环境 ---"
echo "XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP  DESKTOP_SESSION=$DESKTOP_SESSION  DISPLAY=$DISPLAY"
echo ""

echo "===== 1b. 系统 glibc 版本（决定是否需要内置桥接）====="
if [ -x /lib/aarch64-linux-gnu/libc.so.6 ]; then
  SYS_GLIBC_VER=$(/lib/aarch64-linux-gnu/libc.so.6 2>&1 | head -1)
  echo "$SYS_GLIBC_VER"
  SYS_GLIBC=$(echo "$SYS_GLIBC_VER" | grep -oE '2\.[0-9]+' | head -1)
  if [ -n "$SYS_GLIBC" ] && awk "BEGIN{exit !($SYS_GLIBC < 2.34)}"; then
    echo ">>> 系统 glibc $SYS_GLIBC < 2.34，本引擎需要 2.34；启动脚本会自动启用内置 glibc 2.35 桥接（engine/glibc-aarch64/）。"
  else
    echo ">>> 系统 glibc $SYS_GLIBC >= 2.34，可直接原生运行。"
  fi
else
  echo "  (未找到 /lib/aarch64-linux-gnu/libc.so.6)"
fi
echo "--- 内置 glibc 桥接运行时 ---"
if [ -x "$PKG/engine/glibc-aarch64/ld-linux-aarch64.so.1" ]; then
  echo "  OK      内置 glibc 桥接存在 (engine/glibc-aarch64/ld-linux-aarch64.so.1)"
else
  echo "  MISSING 内置 glibc 桥接缺失，老系统将无法启动！请重新解压完整包并执行 chmod +x。"
fi
echo ""

echo "===== 2. 包结构检查 ====="
ls -la "$PKG" 2>&1
echo "--- 关键文件 ---"
chk(){ [ -e "$1" ] && echo "  OK      $1" || echo "  MISSING $1"; }
chk "$PKG/engine/xash3d"
chk "$PKG/engine/libxash.so"
chk "$PKG/engine/libref_gl.so"
chk "$PKG/engine/libSDL2-2.0.so.0"
[ -n "$DATA" ] && {
  chk "$DATA/valve"
  chk "$DATA/cstrike"
  chk "$DATA/cstrike/dlls/cs.so"
  chk "$DATA/cstrike/dlls/cs_arm64.so"
  chk "$DATA/cstrike/dlls/cs_amd64.so"
  chk "$DATA/cstrike/cl_dlls/client.so"
  chk "$DATA/cstrike/cl_dlls/client_arm64.so"
  chk "$DATA/cstrike/cl_dlls/client_amd64.so"
  chk "$DATA/valve/extras.pk3"
  chk "$DATA/cstrike/extras.pk3"
  # 引擎会在游戏根目录(BASEDIR)加载 filesystem_stdio.so，缺失会导致进入地图时段错误
  chk "$PKG/engine/filesystem_stdio.so"
  if [ -f "$DATA/filesystem_stdio.so" ]; then
    echo "  OK      $DATA/filesystem_stdio.so"
  else
    echo "  MISSING $DATA/filesystem_stdio.so   <-- 关键！缺失会导致加载地图时段错误(Segmentation fault)；跑 bash 修复CS1.6.sh 可自动补上"
  fi
} || echo "  [警告] 未找到游戏数据目录（game 或 游戏本体）"
echo ""

echo "===== 3. 引擎二进制架构（应与本机架构一致）====="
EM_FALLBACK=1
elf_machine(){
  # 用 python3 读 e_machine（偏移18, 2字节）：0x3e=x86-64, 0xb7=aarch64, 0x28=arm, 0x01=i386, 0xf3=riscv
  python3 - "$1" <<'PY' 2>/dev/null || EM_FALLBACK=1
import sys,struct
try:
    d=open(sys.argv[1],'rb').read(20)
    m=struct.unpack_from('<H',d,18)[0]
    print({0x3e:'x86-64(amd64)',0xb7:'aarch64(ARM64)',0x28:'ARM32',0x01:'i386',0xf3:'riscv64',0x08:'mips'}.get(m,'未知(0x%X)'%m))
except Exception as e:
    print('读取出错:%s'%e)
PY
}
if [ "$EM_FALLBACK" = 1 ]; then
  if command -v readelf >/dev/null 2>&1; then
    readelf -h "$PKG/engine/xash3d" 2>/dev/null | grep -i "machine:"
  else
    echo "  (无 readelf/python3，跳过；请手动确认)"
  fi
else
  echo "engine/xash3d 架构: $(elf_machine "$PKG/engine/xash3d")"
fi
echo "本机架构 uname -m : $(uname -m)"
echo ">>> 若两者不一致（如引擎是 x86-64 但本机是 aarch64），则架构不匹配，amd64 引擎无法运行。"
echo ""

echo "===== 3b. 游戏库架构（必须与本机一致：aarch64）====="
for f in "$DATA/cstrike/cl_dlls/client.so" "$DATA/cstrike/cl_dlls/client_arm64.so" "$DATA/cstrike/dlls/cs.so" "$DATA/cstrike/dlls/cs_arm64.so"; do
  if [ -f "$f" ]; then
    echo "  $(elf_machine "$f")  <- $f"
  fi
done
echo ">>> 本包为 ARM64 版，上述库应为 aarch64(ARM64)；若为 x86-64 说明复制错了版本。"
echo ""

echo "===== 4. 动态库依赖 (ldd) ====="
for f in engine/xash3d engine/libxash.so engine/libref_gl.so engine/libmenu.so; do
  echo "--- ldd $f ---"
  [ -f "$PKG/$f" ] && ldd "$PKG/$f" 2>&1 || echo "  (文件不存在)"
done
for f in cstrike/cl_dlls/client.so cstrike/dlls/cs.so; do
  echo "--- ldd game/$f ---"
  [ -n "$DATA" ] && [ -f "$DATA/$f" ] && ldd "$DATA/$f" 2>&1 || echo "  (文件不存在)"
done
echo ""

echo "===== 5. 系统关键库是否安装 ====="
for lib in libGL.so.1 libGL.so libopenal.so.1 libopenal.so libSDL2-2.0.so.0 libstdc++.so.6 libgcc_s.so.1; do
  hit=$(ldconfig -p 2>/dev/null | grep -i "$lib")
  if [ -n "$hit" ]; then echo "  FOUND   $lib"; else echo "  MISSING $lib"; fi
done
echo "--- 内置 X11 扩展库（离线环境可能缺失，已随包附带，启动脚本会自动优先使用）---"
if [ -d "$PKG/engine/x11-aarch64" ]; then
  for x in libXfixes.so.3 libXi.so.6 libXrandr.so.2 libXcursor.so.1 libX11.so.6; do
    [ -f "$PKG/engine/x11-aarch64/$x" ] && echo "  OK      内置 $x" || echo "  MISSING 内置 $x"
  done
else
  echo "  [警告] 未找到 engine/x11-aarch64/，X11 扩展缺失时 SDL 会报红字（一般不影响启动）"
fi
echo ""

echo "===== 6. OpenGL / 显示检查 ====="
if command -v glxinfo >/dev/null 2>&1; then
  echo "--- glxinfo ---"
  glxinfo 2>&1 | grep -iE "opengl version|renderer|direct rendering|GLX version" | head
else
  echo "  (无 glxinfo，尝试其他方式)"
  if [ -n "$DISPLAY" ]; then echo "  DISPLAY=$DISPLAY（似乎有 X 显示）"; else echo "  [警告] DISPLAY 为空，可能无图形界面"; fi
fi
echo ""

echo "===== 7. 尝试启动并捕获输出（分别测试：正常 / -soft 软件渲染）====="
if [ -z "$DATA" ]; then
  echo "  [跳过] 未找到游戏数据目录，无法启动"
else
  X11DIR="$PKG/engine/x11-aarch64"
  # 与「启动CS1.6.sh」保持一致：老 glibc 用内置桥接，否则原生
  BRIDGE_PREFIX=()
  if [ -x "$PKG/engine/glibc-aarch64/ld-linux-aarch64.so.1" ]; then
    if [ -n "$SYS_GLIBC" ] && awk "BEGIN{exit !($SYS_GLIBC < 2.34)}"; then
      BRIDGE_PREFIX=( "$PKG/engine/glibc-aarch64/ld-linux-aarch64.so.1" --library-path "$PKG/engine/glibc-aarch64:$X11DIR:$PKG/engine:/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu" )
    fi
  fi
  # 优先用内置 X11 扩展库（离线环境很可能没装 libXfixes/libXi/libXrandr/libXcursor，会导致 SDL 报红字）
  export LD_LIBRARY_PATH="$X11DIR:$PKG/engine:$LD_LIBRARY_PATH"
  export XASH3D_BASEDIR="$DATA"

  run_one(){
    local label="$1"; local extra="$2"; local logf="$PKG/.xash_test.log"
    echo ""
    echo "--- 测试 [$label] : xash3d -game cstrike $extra  (最长 30s) ---"
    rm -f "$logf"
    ( cd "$PKG/engine" && timeout 30 "${BRIDGE_PREFIX[@]}" ./xash3d -game cstrike $extra ) >"$logf" 2>&1
    local rc=$?
    if [ $rc -eq 124 ]; then
      echo "  状态: 30s 仍未退出（超时）-> 极大概率已正常进入游戏/菜单"
    elif [ $rc -eq 0 ]; then
      echo "  状态: 正常退出（退出码 0）"
    elif [ $rc -eq 139 ]; then
      echo "  状态: 段错误崩溃（退出码 139 = 128+SIGSEGV）"
    elif [ $rc -eq 134 ]; then
      echo "  状态: 异常中止（退出码 134 = 128+SIGABRT）"
    else
      echo "  状态: 已退出（退出码 $rc）"
    fi
    echo "  --- 关键日志 ---"
    grep -aiE "Console initialized|Video subsystem|GL_Init|ref_gl|Host_Error|Menu_Init|executing|could not|couldn't|cannot open|undefined symbol|fatal|assert|segmentation|core dumped|转储" "$logf" | head -30
    echo "  --- 完整日志（含崩溃回溯的全部栈帧，勿删减） ---"
    cat "$logf"
  }

  run_one "正常(硬件 GL)" ""
  run_one "软件渲染(-soft)" "-soft"
  echo ""
  echo ">>> 对比结论："
  echo "    · 任一测试 30s 仍在运行 / 日志出现 'Console initialized' 且无明显错误 -> 启动成功（直接 ./启动CS1.6.sh 即可；若黑屏再加 -soft）"
  echo "    · 两个都很快退出且报 GL/视频错误 -> 问题在 OpenGL，请试： LIBGL_ALWAYS_SOFTWARE=1 ./启动CS1.6.sh"
  echo "    · 出现 'Host_Error' / 'couldn't init' / 'Segmentation' -> 把本报告（含上面日志）发我"
fi
echo ""

echo "===== 8. 引擎日志文件（如有）====="
for log in "$PKG/engine/xash3d.log" "$PKG/xash3d.log" "$DATA/cstrike/console.log" "$DATA/valve/console.log" "$PKG/console.log"; do
  if [ -f "$log" ]; then echo "--- $log ---"; cat "$log" 2>/dev/null | tail -60; fi
done
echo ""

echo "===== 9. 已安装的 Xash3D 相关软件包（仅供排查）====="
(command -v dpkg >/dev/null 2>&1 && dpkg -l 2>/dev/null | grep -iE "mesa|libgl1|libopenal|libsdl2|xash|wine" ) || echo "  (非 Debian/无 dpkg)"
echo ""
echo "############## 报告结束 ##############"
} > "$REPORT" 2>&1

echo "已生成诊断报告："
echo "  $REPORT"
echo "请把该文件发回给我分析（可直接拖进对话）。"
