#!/bin/bash
# ============================================================
#  CS 1.6 (Xash3D) 就地修复脚本
#  作用：把中文目录 游戏本体 -> game（Xash3D 对非 ASCII 路径支持差），
#        补执行权限，清掉 Windows 残留 DLL。无需重新下载。
#  用法：把本脚本放进 CS1.6-UOS-Xash3D 目录，终端执行  bash 修复CS1.6.sh
# ============================================================
PKG="$(cd "$(dirname "$0")" && pwd)"
echo "工作目录: $PKG"

# 1) 中文目录 -> 英文目录
if [ -d "$PKG/游戏本体" ]; then
  if [ -d "$PKG/game" ]; then
    echo "[提示] 已存在 game/，跳过重命名；原 游戏本体/ 仍在，可手动合并后删除。"
  else
    mv "$PKG/游戏本体" "$PKG/game" && echo "[已修复] 游戏本体 -> game" || echo "[失败] 重命名失败，请手动重命名"
  fi
else
  echo "[信息] 未发现中文目录 游戏本体（已是英文或不在此目录）"
fi

# 2) 补执行权限
chmod +x "$PKG/engine/xash3d" 2>/dev/null && echo "[已修复] engine/xash3d 可执行权限"
chmod +x "$PKG/启动CS1.6.sh" 2>/dev/null && echo "[已修复] 启动CS1.6.sh 可执行权限"
chmod +x "$PKG/engine/"*.so 2>/dev/null
# 内置 glibc 桥接运行时（老系统需要，其加载器必须可执行）
chmod +x "$PKG/engine/glibc-aarch64/"* 2>/dev/null && echo "[已修复] engine/glibc-aarch64/ 执行权限"
# 内置 X11 客户端库（离线环境缺 XFixes/XInput2/XRandR/Xcursor 时由启动脚本优先加载）
chmod +x "$PKG/engine/x11-aarch64/"* 2>/dev/null && echo "[已修复] engine/x11-aarch64/ 执行权限"

# 2b) 确保 filesystem_stdio.so 同时存在于 game/（引擎会在游戏根目录找它，缺失会导致加载地图时段错误崩溃）
if [ -d "$PKG/game" ] && [ -f "$PKG/engine/filesystem_stdio.so" ] && [ ! -f "$PKG/game/filesystem_stdio.so" ]; then
  cp -f "$PKG/engine/filesystem_stdio.so" "$PKG/game/filesystem_stdio.so" \
    && echo "[已修复] 已补 game/filesystem_stdio.so（引擎必需的文件系统模块）"
fi

# 3) 清掉 Windows 残留 DLL（Linux 用不到，可能干扰）
n=$(find "$PKG/game" -iname "*.dll" 2>/dev/null | wc -l)
if [ "$n" -gt 0 ]; then
  find "$PKG/game" -iname "*.dll" -delete 2>/dev/null
  echo "[已清理] 删除 $n 个残留 .dll 文件"
fi

# 4) 校验
echo ""
echo "===== 修复后校验 ====="
[ -d "$PKG/game" ] && echo "  OK  game/ 存在" || echo "  MISSING game/"
[ -x "$PKG/engine/xash3d" ] && echo "  OK  engine/xash3d 可执行" || echo "  FAIL engine/xash3d"
[ -f "$PKG/game/cstrike/dlls/cs.so" ] && echo "  OK  cstrike/dlls/cs.so" || echo "  FAIL cs.so"
echo ""
echo "现在请尝试启动："
echo "  cd $PKG"
echo "  ./启动CS1.6.sh"
echo "若仍无法运行，请运行  bash 诊断CS1.6.sh  并把生成的 CS1.6诊断报告.txt 发回。"
