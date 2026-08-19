#!/usr/bin/env bash
# グローバル PreToolUse ガード — 秘密情報ファイルへの書き込みを拒否する。
#
# 設定: ~/.claude/settings.json の hooks.PreToolUse に matcher "Edit|Write" で登録する。
# 入力: ツール入力の JSON が stdin で渡る。
# 出力: exit 0 = 通過 / exit 2 = ブロックし stderr の内容を Claude に見せる。
#
# permissions の deny と役割が重なるが、こちらは「パターンで書ききれない条件」と
# 「deny の設定漏れに対する保険」を担う。両方あってよい（fail-closed）。

set -uo pipefail

input="$(cat 2>/dev/null || true)"

# JSON から file_path を素朴に抽出する。jq に依存しない（未インストール環境で沈黙するため）。
fp="$(printf '%s' "$input" \
  | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' \
  | head -1)"

# file_path を持たないツール入力は対象外
[ -z "$fp" ] && exit 0

deny() {
  printf '⛔ %s\n   対象: %s\n' "$1" "$fp" >&2
  exit 2
}

# --- .env 実ファイル ---------------------------------------------------------
# .env.example / .env.sample / .env.template は非機密の雛形なので許可する。
if printf '%s' "$fp" | grep -qE '(^|/)\.env(\.(local|production|prod|development|dev|test|staging))?$'; then
  deny "秘密情報ファイルへの書き込みは禁止です。非機密の雛形は .env.example に書いてください。"
fi

# --- secrets ディレクトリ ----------------------------------------------------
if printf '%s' "$fp" | grep -qE '(^|/)(secrets|\.secrets)/'; then
  deny "secrets/ 配下への書き込みは禁止です。"
fi

# --- 鍵・証明書 --------------------------------------------------------------
if printf '%s' "$fp" | grep -qE '(^|/)\.ssh/|\.(pem|key|p12|pfx|jks)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)(\.pub)?$'; then
  deny "鍵・証明書ファイルへの書き込みは禁止です。"
fi

# --- クラウド認証情報 --------------------------------------------------------
if printf '%s' "$fp" | grep -qE '(^|/)\.(aws|gcloud|kube|docker|npmrc|pypirc|netrc)(/|$)|(^|/)credentials$|service-account.*\.json$'; then
  deny "認証情報ファイルへの書き込みは禁止です。"
fi

exit 0
