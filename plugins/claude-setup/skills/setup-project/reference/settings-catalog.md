# settings.json 部品カタログ

`.claude/settings.json` に入れる部品を**意図別**に並べたもの。全部入れるのではなく、
Phase 2 のインタビューで確認した「触られたら困るもの」「外部に出る操作」に該当する部品だけを選ぶ。

各部品には原則ID（`agent-essence` の体系）と**理由**を付けてある。生成した settings.json に
コメントを残すときは理由のほうを書く。ルールの列挙より理由のほうが未知のケースに汎化する（→E-2）。

---

## 0. スキーマ — ここを間違えると黙って無効になる

### hooks の正しい形

```jsonc
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "..." }
        ]
      }
    ]
  }
}
```

**よくある間違い**: `matcher` と `command` を同じ階層に直書きする形。

```jsonc
// ✗ これは効かない
"PostToolUse": [ { "matcher": "Write|Edit", "command": "..." } ]
```

`hooks` 配列へのネストが必須。ネストを忘れても**エラーにならず静かに無視される**ので、
設定した気になったまま何も起きない状態になる。生成後は必ず Phase 5 の動作確認を通す。

補足:
- `matcher` を省略するとそのイベントの全発火にマッチする（`SessionStart` / `Stop` 等で使う）
- `"async": true` を付けると完了を待たない（通知・音などブロックすべきでないものに使う）
- イベント名: `PreToolUse` / `PostToolUse` / `UserPromptSubmit` / `SessionStart` / `Stop` /
  `SubagentStart` / `SubagentStop` / `Notification`

### hook スクリプトの入出力

- **入力**: ツール入力の JSON が **stdin** で渡る。`$TOOL_INPUT_FILE_PATH` のような環境変数は存在しない。
  ファイルパスは stdin の JSON から `file_path` を取り出す
- **出力**: `exit 0` = 通過 / `exit 2` = **ブロックし、stderr の内容を Claude に見せる**
- `$CLAUDE_PROJECT_DIR` はプロジェクトルートを指す

### hook の実行環境 — 対話シェルとは別物

hook は**素の bash** で走る。ユーザーの `.zshrc` / `.bashrc` は読まれない。したがって:

| 使えないもの | 代わりに |
|---|---|
| シェルの alias / function | 実体のあるコマンドだけを呼ぶ |
| `rg` | **`grep`**。`rg` は環境によっては実体が無く、Claude Code のシェル関数として提供されている |
| `nvm` / `pyenv` 等で切り替えた版 | フルパス、または `npx` 経由 |
| CWD の前提 | `$CLAUDE_PROJECT_DIR` を基準にする |

**特に `rg` は要注意。** チャット上の Bash では動くのに hook では動かないので、
「手元で試したら動いた」が通用しない。しかも `command -v rg` でガードしていると、
**検査ごと黙ってスキップされて素通りする**（ガードの fail-open。→S-1.5 に反する）。

外部コマンドに依存する検査を書くときは、**そのコマンドが無い場合にどちらへ倒れるか**を決める:

- **整形・補助** → 無ければ何もしない（`|| true`）
- **禁止語・秘密情報などの関門** → 常に存在するコマンド（`grep` / `sed`）だけで書く。
  「無ければスキップ」にしない

### `grep` はあるが、実装は同じではない

`grep` の実体は GNU grep / BSD grep（macOS 既定）/ ugrep などに分かれ、**挙動が一致しない**。
実装差に踏み込む書き方をしない。

代表例: **パターンファイルに空行があると、GNU grep は全行にマッチする**。
macOS では起きないので開発機では気づけず、Linux ユーザーだけが踏む。

```bash
# ✗ ファイルをそのまま渡す — 空行1つで全行マッチになりうる
grep -F -f wordlist.txt "$target"

# ✓ コメントと空行を落としてから渡し、空になったら検査ごとやめる
pat="$(grep -v '^[[:space:]]*#' wordlist.txt | grep -v '^[[:space:]]*$')"
[ -z "$pat" ] && exit 0
printf '%s\n' "$pat" | grep -F -f - "$target"
```

同様に、`grep -P`（PCRE）・`sed -i` の引数形式・`echo` のエスケープ解釈も実装差が出る。
hook では `sed -E` と POSIX の範囲に留め、`printf` を使う。

### permissions の記法

| 形 | 例 | 意味 |
|---|---|---|
| `Bash(cmd:*)` | `Bash(npm test:*)` | サブコマンド以下にマッチ |
| `Bash(cmd*)` | `Bash(git push --force*)` | 前方一致 |
| `Read(glob)` | `Read(**/.env)` | 読み取り |
| `Edit(glob)` | `Edit(**/*.test.*)` | 編集（Write も含む） |
| `WebFetch(domain:...)` | `WebFetch(domain:github.com)` | 取得先ドメイン |

評価順は **deny → ask → allow**。deny が最優先で、allow では覆せない。

---

## 1. 評価基準を守る（→C-5 報酬ハッキング / →S-1）

エージェントは「テストを通す」最短経路を選ぶ。**テスト自体の書き換えが最短経路になりうる**ので、
そこを物理的に閉じる。これを閉じないと、以降のあらゆる検証が信用できなくなる。

```jsonc
"deny": [
  "Edit(**/*.test.*)",
  "Edit(**/*.spec.*)",
  "Edit(**/__tests__/**)",
  "Edit(**/e2e/**)"
]
```

lint / 型の設定も同じ理由で守る。閾値を下げれば緑になるため。

```jsonc
"deny": [
  "Edit(tsconfig.json)",
  "Edit(.eslintrc*)",
  "Edit(eslint.config.*)",
  "Edit(biome.json)",
  "Edit(ruff.toml)",
  "Edit(pyproject.toml)"     // [tool.ruff] 等を含む場合のみ
]
```

**文書・ワークフロー型では対象が変わる**。守るべきは評価軸そのもの:

```jsonc
"deny": [
  "Edit(evaluation.md)",
  "Edit(.claude/evaluation/**)"
]
```

> **判断**: 実装と評価が同じセッションで動くなら必ず入れる。
> 評価を別セッション・別エージェントに分離しているなら緩めてよい。

---

## 2. 自分のルールを書き換えさせない（→C-5 / →S-1）

権限設定そのものを書き換えられると、他の全ての deny が無意味になる。**最初に入れる**。

```jsonc
"deny": [
  "Edit(.claude/settings.json)",
  "Edit(.claude/settings.local.json)",
  "Edit(.claude/hooks/**)"
]
```

CLAUDE.md 自体を deny するかは分かれる。運用中に育てたいので**通常は deny しない**。
ただし「CLAUDE.md の制約を消して作業を通す」が観測されたら追加する。

---

## 3. 不可逆操作を閉じる（→S-1.3 最小権限 / →C-7 校正盲）

エージェントは**間違ったコマンドを高い確信度で実行する**。取り返しがつかないものは物理的に塞ぐ。
可逆なものを優先する（`git commit` > `git push --force`）。

```jsonc
"deny": [
  "Bash(git push --force*)",
  "Bash(git push -f*)",
  "Bash(git push origin +*)",
  "Bash(git reset --hard*)",
  "Bash(git clean -fd*)",
  "Bash(rm -rf *)"
]
```

---

## 4. 外の世界に出る操作（→S-1.3）

「ローカルで壊れる」と「外に出て壊れる」は別の重さ。デプロイ・公開・マージは歯止めを付ける。

```jsonc
"deny": [
  "Bash(gh pr merge:*)",
  "Bash(gh release:*)",
  "Bash(npm publish*)",
  "Bash(gh api -X POST:*)",
  "Bash(gh api -X PUT:*)",
  "Bash(gh api -X PATCH:*)",
  "Bash(gh api -X DELETE:*)"
]
```

デプロイ系はプロジェクトで検出したものを足す（`vercel deploy --prod`、`wrangler publish`、
`firebase deploy`、`terraform apply` 等）。

> **判断**: 「外部公開・実決済・本番系」に触るコマンドがあるか。
> Phase 2 のインタビューで「外部に出る操作はあるか」を聞くのはこのため。

---

## 5. 秘密情報（→S-1.1 出所と露出先）

読み取りも書き込みも塞ぐ。読めてしまうと、そこからレポートやコミットへ**転記**される経路が生まれる。

```jsonc
"deny": [
  "Read(**/.env)",
  "Read(**/.env.local)",
  "Read(**/.env.production)",
  "Read(**/.env.development)",
  "Edit(**/.env)",
  "Edit(**/.env.local)",
  "Read(**/secrets/**)",
  "Edit(**/secrets/**)"
]
```

`.env.example` / `.env.sample` は**塞がない**（非機密の雛形として必要）。
より強く守るなら PreToolUse hook を併用する（§8）。

---

## 6. allow — 摩擦を減らす（→C-1 帯域 / →V-1.3）

deny だけ書くと「毎回聞かれる」状態が残り、確認が形骸化する。
**読み取り専用・冪等なコマンドは allow に入れて、確認を本当に危ないものへ集中させる。**

検出したパッケージマネージャに合わせて選ぶ:

```jsonc
// Node
"allow": [
  "Bash(npm test:*)", "Bash(npm run lint:*)", "Bash(npm run typecheck:*)",
  "Bash(npx tsc --noEmit*)", "Bash(pnpm test:*)"
]
// Python
"allow": [
  "Bash(pytest:*)", "Bash(ruff check:*)", "Bash(mypy:*)", "Bash(uv run:*)"
]
// Go
"allow": [ "Bash(go test:*)", "Bash(go vet:*)", "Bash(go build:*)" ]
```

種別を問わず入れてよいもの:

```jsonc
"allow": [
  "Bash(rg:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(git status:*)",
  "Bash(git diff:*)", "Bash(git log:*)"
]
```

> **原則**: allow は「読むだけ・何度やっても同じ」に限る。
> `npm install` のように状態を変えるものを安易に allow へ入れない。

---

## 7. PostToolUse — 即時フィードバック（→V-1.2 速いほど強い）

同じ検査なら遅い場所より早い場所で落とす。人間レビュー < CI < プリコミット < **ツール直後**。
プロンプトで「フォーマットして」と書いても忘れるが、hook なら忘れようがない（→V-1）。

```jsonc
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        { "type": "command", "command": "bash .claude/hooks/format-changed.sh" }
      ]
    }
  ]
}
```

`.claude/hooks/format-changed.sh`（検出したフォーマッタに合わせて中身を差し替える）:

```bash
#!/usr/bin/env bash
set -uo pipefail
input="$(cat 2>/dev/null || true)"
fp="$(printf '%s' "$input" | sed -nE 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
[ -z "$fp" ] || [ ! -f "$fp" ] && exit 0

case "$fp" in
  *.ts|*.tsx|*.js|*.jsx|*.json)  npx biome check --write "$fp" >/dev/null 2>&1 || true ;;
  *.py)                          ruff format "$fp" >/dev/null 2>&1 || true ;;
  *.go)                          gofmt -w "$fp" >/dev/null 2>&1 || true ;;
  *.md)                          npx textlint --fix "$fp" >/dev/null 2>&1 || true ;;
esac
exit 0
```

**必ず `|| true` で握る**。フォーマッタが未インストールの環境で `exit 2` になると、
無関係な編集が全部ブロックされて作業が止まる。整形は「できたらやる」であって関門ではない。

---

## 7.5 スキル使用ログ — 棚卸しの定量データ（→E-1.1 / K-2.3）

スキルの棚卸しは「説明する機会に自然に気づく」だけでは漏れる。
**使用/未使用を事実で切り分ける観測面**が無いと、増え続けるスキルを消す根拠が作れない。
呼び出し時刻とスキル名**だけ**を記録する（引数は記録しない —
自由入力に PII が載りうるため）。

```jsonc
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Skill",
      "hooks": [
        { "type": "command", "command": "bash .claude/hooks/skill-usage.sh" }
      ]
    }
  ]
}
```

`.claude/hooks/skill-usage.sh`:

```bash
#!/usr/bin/env bash
# スキル呼び出しの定量計測。観測面が本作業を壊してはならない＝常に exit 0。
set -uo pipefail
dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
input="$(cat 2>/dev/null || true)"
skill="$(printf '%s' "$input" | sed -nE 's/.*"skill"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
[ -n "$skill" ] || exit 0
case "$skill" in *[!A-Za-z0-9:._-]*) exit 0 ;; esac   # 想定外の値でログ行を壊さない
log="$dir/.claude/skill-usage.log"
mkdir -p "$dir/.claude" 2>/dev/null || exit 0
printf '%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$skill" >>"$log" 2>/dev/null || true
exit 0
```

- `.claude/skill-usage.log` は **gitignore に追加する**（マシン固有の運用ログ）
- 棚卸し時は `cut -f2 .claude/skill-usage.log | sort | uniq -c | sort -rn` で使用回数が出る
- 初期からでも安い（1呼び出し1行）。スキルが増えてから入れても過去は取れない

## 8. PreToolUse — 関門（→S-1.5 fail-closed）

permissions の glob で表しきれない条件はここで見る。`exit 2` でブロックし、
**stderr に理由を書くと Claude がそれを読んで方針を変える**（→V-2 ループを閉じる）。

```jsonc
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        { "type": "command", "command": "bash .claude/hooks/guard.sh" }
      ]
    }
  ]
}
```

`~/.claude/hooks/guard.sh` を `setup-global` で既に入れている場合、**プロジェクト側で重複させない**。
プロジェクト固有の条件（この案件だけ触られたくないディレクトリ等）がある場合にだけ追加する。

---

## 9. 入れない判断も記録する

カタログの部品を**採用しなかった理由**を、生成する CLAUDE.md か settings.json のコメントに1行残す。
残さないと、次のセッションが「抜けている」と判断して勝手に足すか、逆に必要な追加をためらう。

```jsonc
// deny に Edit(**/*.test.*) を入れていない:
// このプロジェクトはテスト自体を成果物として育てる段階のため。
// 実装フェーズに入ったら追加する。
```

---

## 10. deny は最終防衛線であって主たる制御ではない（→V-1.3）

使えないツールや禁止アクションは、**呼び出し時に拒否するより、そもそも選択肢に出さないほうが強い**。
モデルが見えない選択肢は選べないし、帯域の節約にもなる（→C-1）。

したがって:
1. まず **CLAUDE.md で「何をどう検証するか」を書く**（正しい経路を示す）
2. 次に **hook で自動的に矯正する**（V-1）
3. 最後に **deny で塞ぐ**（S-1.3）

deny だけが厚くて CLAUDE.md が空、という構成は「禁止は多いが何をすべきか分からない」状態になる。
生成時はこの順序で作る。
