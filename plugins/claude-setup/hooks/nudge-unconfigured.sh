#!/usr/bin/env bash
# SessionStart ナッジ — ハーネスが未設定のディレクトリでだけ、1行だけ案内する。
#
# SessionStart の stdout はコンテキストに載る。常時出すとそれ自体がノイズになるので
# (→C-1 帯域はゼロサム)、条件を強く絞る:
#   - CLAUDE.md / AGENTS.md / .claude/settings*.json のいずれも無い
#   - ホームディレクトリ直下ではない
#   - そのディレクトリで一度も案内していない
#   - CLAUDE_SETUP_NO_NUDGE=1 が設定されていない
#
# 何も言うことが無ければ黙る。それが既定。

set -uo pipefail

[ "${CLAUDE_SETUP_NO_NUDGE:-}" = "1" ] && exit 0

dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# ホーム直下や / でセッションを開いただけのときは出さない
[ "$dir" = "$HOME" ] && exit 0
[ "$dir" = "/" ] && exit 0

# 既にハーネスがあるなら用は無い
for f in "$dir/CLAUDE.md" "$dir/AGENTS.md" \
         "$dir/.claude/settings.json" "$dir/.claude/settings.local.json"; do
  [ -f "$f" ] && exit 0
done

# 同じディレクトリで繰り返し言わない（案内は1回で足りる）
stamp="$HOME/.claude/.claude-setup-nudged"
key="$(printf '%s' "$dir" | tr -c 'A-Za-z0-9/.-' '_')"
if [ -f "$stamp" ] && grep -qxF "$key" "$stamp" 2>/dev/null; then
  exit 0
fi
mkdir -p "$(dirname "$stamp")" 2>/dev/null || true
printf '%s\n' "$key" >> "$stamp" 2>/dev/null || true

echo "このディレクトリには CLAUDE.md も .claude/settings.json もありません。/setup-project でハーネスを作れます（この案内が不要なら環境変数 CLAUDE_SETUP_NO_NUDGE=1）。"
exit 0
