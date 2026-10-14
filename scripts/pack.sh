#!/usr/bin/env bash
# Trae 跨设备迁移 · 源端一键打包（macOS/Linux）
# 用法: ./pack.sh --project /path/to/project [--out DIR] [--solo] [--with-deps] [--secrets-from DIR]
# 产出: project-full.tar.gz / trae-cn-final.tar.gz / trae-appdata-chat.tar.gz
#       [trae-appdata-solo-chat.tar.gz] / [secrets.tar.gz] / SHA256SUMS.txt
set -euo pipefail

PROJECT=""; OUT=""; SOLO=0; WITH_DEPS=0; SECRETS_FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --solo) SOLO=1; shift ;;
    --with-deps) WITH_DEPS=1; shift ;;
    --secrets-from) SECRETS_FROM="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$PROJECT" ]] && { echo "❌ 必须提供 --project <项目路径>"; exit 2; }
[[ -d "$PROJECT" ]] || { echo "❌ 项目路径不存在: $PROJECT"; exit 2; }
PROJECT="$(cd "$PROJECT" && pwd)"
PROJ_NAME="$(basename "$PROJECT")"
: "${SECRETS_FROM:=$PROJECT}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-$HOME/Desktop/trae-migration-$STAMP}"
mkdir -p "$OUT"

echo "==> [0/5] 环境检查"
if pgrep -if "Trae" >/dev/null 2>&1; then
  echo "⚠️  检测到 Trae 正在运行。为保证聊天库一致，请完全退出 Trae 后重跑；"
  echo "    或确认退出后按回车继续..."
  read -r _
fi

echo "==> [1/5] 打包项目（$PROJ_NAME）"
EXCLUDES=(--exclude node_modules --exclude .venv --exclude venv --exclude __pycache__ --exclude dist)
[[ $WITH_DEPS -eq 1 ]] && EXCLUDES=()
tar -czf "$OUT/project-full.tar.gz" -C "$(dirname "$PROJECT")" "${EXCLUDES[@]}" "$PROJ_NAME"

echo "==> [2/5] 打包全局配置（~/.trae-cn）"
if [[ -d "$HOME/.trae-cn" ]]; then
  cp -R "$HOME/.trae-cn" "$OUT/.trae-cn"
  find "$OUT/.trae-cn" -name "*.log" -delete 2>/dev/null || true
  find "$OUT/.trae-cn" -type d \( -name "Cache*" -o -name "logs" \) -prune -exec rm -rf {} + 2>/dev/null || true
  tar -czf "$OUT/trae-cn-final.tar.gz" -C "$OUT" ".trae-cn"
  rm -rf "$OUT/.trae-cn"
else
  echo "    跳过：未找到 ~/.trae-cn"
fi

echo "==> [3/5] 打包应用数据（聊天库）"
APP_BASE="$HOME/Library/Application Support"
[[ -d "$APP_BASE/Trae CN" ]] && tar -czf "$OUT/trae-appdata-chat.tar.gz" -C "$APP_BASE" "Trae CN"
if [[ $SOLO -eq 1 && -d "$APP_BASE/TRAE SOLO CN" ]]; then
  tar -czf "$OUT/trae-appdata-solo-chat.tar.gz" -C "$APP_BASE" "TRAE SOLO CN"
fi

echo "==> [4/5] 打包密钥"
ITEMS=()
[[ -f "$SECRETS_FROM/.env" ]] && ITEMS+=(.env)
[[ -d "$SECRETS_FROM/deploy/secrets" ]] && ITEMS+=(deploy/secrets)
if [[ ${#ITEMS[@]} -gt 0 ]]; then
  tar -czf "$OUT/secrets.tar.gz" -C "$SECRETS_FROM" "${ITEMS[@]}"
else
  echo "    跳过：未发现 .env 或 deploy/secrets"
fi

echo "==> [5/5] 生成校验与汇总"
(cd "$OUT" && shasum -a 256 -- *.tar.gz > SHA256SUMS.txt)
echo ""
echo "✅ 打包完成：$OUT"
ls -lh "$OUT" | awk 'NR>1 {printf "    %-38s %s\n", $NF, $5}'
echo ""
echo "📦 传输方式（任选其一）：AirDrop / U盘 / 网盘 / 局域网 scp"
echo "   传输五件套：project-full.tar.gz · trae-cn-final.tar.gz ·"
echo "   trae-appdata-chat.tar.gz · secrets.tar.gz（如有）· SHA256SUMS.txt"
echo "⚠️  迁移包含密钥与聊天记录，走可信通道，传输完在旧设备保留 1-2 周再删"
echo ""
echo "→ 新电脑上装好 Trae 后，把迁移包放到任意目录，说一句："
echo '   「迁移包在 <路径>，帮我恢复」'
