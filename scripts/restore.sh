#!/usr/bin/env bash
# Trae 跨设备迁移 · 目标端一键恢复（macOS/Linux）
# 用法: ./restore.sh --dir <迁移包目录> [--project-dest DIR] [--skip-project]
# 退出码: 0 成功 / 2 参数错 / 3 项目已存在(需用户决策) / 4 校验失败
set -euo pipefail

PKG=""; DEST="$HOME"; SKIP_PROJECT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) PKG="$2"; shift 2 ;;
    --project-dest) DEST="$2"; shift 2 ;;
    --skip-project) SKIP_PROJECT=1; shift ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$PKG" ]] && { echo "❌ 必须提供 --dir <迁移包目录>"; exit 2; }
[[ -d "$PKG" ]] || { echo "❌ 迁移包目录不存在: $PKG"; exit 2; }
PKG="$(cd "$PKG" && pwd)"
DEST="$(cd "$DEST" && pwd)"

echo "==> [1/7] 校验传输完整性（SHA256）"
if [[ -f "$PKG/SHA256SUMS.txt" ]]; then
  (cd "$PKG" && shasum -a 256 -c SHA256SUMS.txt) || { echo "❌ 校验失败，重新传输"; exit 4; }
else
  echo "    跳过：未找到 SHA256SUMS.txt"
fi

PROJ_PATH=""
if [[ $SKIP_PROJECT -eq 0 && -f "$PKG/project-full.tar.gz" ]]; then
  echo "==> [2/7] 恢复项目"
  PROJ_NAME="$(tar -tzf "$PKG/project-full.tar.gz" | head -1 | cut -d/ -f1)"
  if [[ -e "$DEST/$PROJ_NAME" ]]; then
    echo "❌ 目标已存在: $DEST/$PROJ_NAME"
    echo "    处理方式交由用户确认：复用(--skip-project) / 备份后替换 / 改 --project-dest 换位置"
    exit 3
  fi
  tar -xzf "$PKG/project-full.tar.gz" -C "$DEST"
  PROJ_PATH="$DEST/$PROJ_NAME"
  echo "    已恢复 → $PROJ_PATH"
elif [[ $SKIP_PROJECT -eq 1 ]]; then
  echo "==> [2/7] 按要求跳过项目恢复"
  for d in "$DEST"/*/; do [[ -d "${d}.git" ]] && PROJ_PATH="${d%/}" && break; done
fi

echo "==> [3/7] 恢复全局配置（并入 ~/.trae-cn，先备份）"
if [[ -f "$PKG/trae-cn-final.tar.gz" ]]; then
  if [[ -d "$HOME/.trae-cn" ]]; then
    BAK="$HOME/.trae-cn.bak-$(date +%Y%m%d-%H%M%S)"
    cp -R "$HOME/.trae-cn" "$BAK"
    echo "    已备份 → $BAK"
  fi
  TMPD="$(mktemp -d)"
  tar -xzf "$PKG/trae-cn-final.tar.gz" -C "$TMPD"
  mkdir -p "$HOME/.trae-cn"
  cp -R "$TMPD/.trae-cn/" "$HOME/.trae-cn/"
  rm -rf "$TMPD"
  echo "    已并入 ~/.trae-cn"
fi

if [[ -n "$PROJ_PATH" ]]; then
  echo "==> [4/7] 恢复密钥并收紧权限"
  if [[ -f "$PKG/secrets.tar.gz" ]]; then
    tar -xzf "$PKG/secrets.tar.gz" -C "$PROJ_PATH"
    [[ -f "$PROJ_PATH/.env" ]] && chmod 600 "$PROJ_PATH/.env" || true
    find "$PROJ_PATH/deploy/secrets" -type f -exec chmod 600 {} + 2>/dev/null || true
  fi

  echo "==> [5/7] 清理 git 跨平台遗留"
  if [[ -d "$PROJ_PATH/.git" ]]; then
    git -C "$PROJ_PATH" config --local --unset-all http.proxy 2>/dev/null || true
    git -C "$PROJ_PATH" config --local --unset-all https.proxy 2>/dev/null || true
    git -C "$PROJ_PATH" config --local core.autocrlf false
    git -C "$PROJ_PATH" log --oneline -1 2>/dev/null || true
  fi
fi

echo "==> [6/7] 解压聊天库到 work/（不直接进应用数据目录）"
WORK="$PKG/work"; mkdir -p "$WORK"
[[ -f "$PKG/trae-appdata-chat.tar.gz" ]] && tar -xzf "$PKG/trae-appdata-chat.tar.gz" -C "$WORK"
[[ -f "$PKG/trae-appdata-solo-chat.tar.gz" ]] && tar -xzf "$PKG/trae-appdata-solo-chat.tar.gz" -C "$WORK"

echo "==> [7/7] 生成 migration-job.json（待用户确认后执行）"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
gen_job() { # $1=source_dir $2=target_dir $3=outfile
  local mid; mid="$(uuidgen)"
  cat > "$3" <<EOF
{
  "migrationId": "$mid",
  "source": "$1",
  "target": "$2",
  "status": "pending",
  "removeApp": false
}
EOF
}
TARGET_APPDATA="$HOME/Library/Application Support/Trae CN"
[[ -d "$WORK/Trae CN" && -d "$TARGET_APPDATA" ]] && \
  gen_job "$WORK/Trae CN" "$TARGET_APPDATA" "$WORK/migration-job.json" && \
  echo "    已生成: $WORK/migration-job.json"
SOLO_TARGET="$HOME/Library/Application Support/TRAE SOLO CN"
[[ -d "$WORK/TRAE SOLO CN" && -d "$SOLO_TARGET" ]] && \
  gen_job "$WORK/TRAE SOLO CN" "$SOLO_TARGET" "$WORK/migration-job-solo.json" && \
  echo "    已生成: $WORK/migration-job-solo.json（SOLO 分库单独迁移）"

echo ""
echo "✅ 自动恢复完成。剩余步骤（AI 引导执行）："
[[ -n "$PROJ_PATH" ]] && echo "    1. 项目 $PROJ_PATH：安装依赖并启动验证（Node 20+，与源端一致）"
echo "    2. 记忆挂接：在 Trae 中打开项目让 AI 响应一次 → 合并项目记忆（见 references/data-locations.md §2.2）"
[[ -f "$WORK/migration-job.json" ]] && echo "    3. 聊天迁移：向用户确认后，把 migration-job.json 复制到 target 根目录并执行"
[[ -f "$WORK/migration-job.json" ]] && echo "       open 'trae-cn://migration?migrationId=<json 内的 migrationId>'（详情见 references/chat-migration.md）"
echo "    4. 按 references/chat-migration.md §验收清单逐项打勾"
