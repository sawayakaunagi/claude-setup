---
name: setup-global
description: ~/.claude（ユーザースコープ）を初期化する。グローバル CLAUDE.md・秘密情報ガード hook・推奨 permissions を入れる。「グローバル設定して」「~/.claude を初期化」「初期セットアップ」「Claude Code を使い始める」で発動。初回に一度だけ実行する。
---

# setup-global

`~/.claude` を初期化する。**初回に一度だけ**実行するもの。
プロジェクト側のハーネスは `/setup-project` が担当する。

- **Input**: なし
- **Output**: `~/.claude/CLAUDE.md` / `~/.claude/hooks/guard.sh` / `~/.claude/settings.json` の
  permissions と hooks。**既存ファイルは上書きしない**

## 最初に伝える方針

作業を始める前に、これを一言で伝える。

> グローバルは**薄く保つ**。ここに書いたものは全セッションの先頭に常時載り、
> 無関係なプロジェクトの作業中もコンテキストを占め続ける。
> だから「全プロジェクトで例外なく成り立つこと」だけを入れる。

この方針を共有しないまま設定を足すと、後から「便利そうだから」で肥大化する（→C-1）。

---

## Phase 1. 現状確認

```bash
ls ~/.claude/CLAUDE.md ~/.claude/settings.json 2>/dev/null
ls ~/.claude/hooks/ 2>/dev/null
[ -f ~/.claude/settings.json ] && cat ~/.claude/settings.json
```

| 状態 | 進め方 |
|---|---|
| 何も無い | **初期化モード** — テンプレートから作る |
| 既にある | **差分モード** — 不足分だけを提案する |

**差分モードでは既存ファイルを絶対に上書きしない。**
特に `~/.claude/settings.json` はエディタ連携・statusLine・プラグイン有効化など、
本スキルの関心外の設定が入っている。壊すと影響が全プロジェクトに及ぶ。

**変更前に必ずバックアップを取る**:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%Y%m%d-%H%M%S)
```

---

## Phase 2. `~/.claude/CLAUDE.md`

`templates/CLAUDE.md.tmpl`（本スキル同梱）を読み、プレースホルダを埋めて配置する。

埋めるもの:
- `{日本語}` — 応答言語。ユーザーに確認する

既にある場合は、テンプレートにあって既存に無いセクションだけを**追記案として提示**する。
既存の記述と矛盾する提案はしない。

---

## Phase 3. `~/.claude/hooks/guard.sh`

`templates/guard.sh`（本スキル同梱）を `~/.claude/hooks/guard.sh` に配置し、実行権を付ける。

```bash
mkdir -p ~/.claude/hooks
cp <本スキル>/templates/guard.sh ~/.claude/hooks/guard.sh
chmod +x ~/.claude/hooks/guard.sh
```

`~/.claude/settings.json` の `hooks` に登録する（**`hooks` 配列へのネストが必須**。
忘れるとエラーにならず静かに無視される）:

```jsonc
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Edit|Write",
      "hooks": [
        { "type": "command", "command": "bash ~/.claude/hooks/guard.sh" }
      ]
    }
  ]
}
```

既に `PreToolUse` がある場合は、既存エントリを消さずに追加する。

### 配置したら必ず動作確認する（→C-4）

登録しただけでは効いているか分からない。**実際に叩いて確かめる**:

```bash
printf '{"file_path":"/tmp/.env"}' | bash ~/.claude/hooks/guard.sh; echo "exit=$?"   # 期待: exit=2
printf '{"file_path":"/tmp/a.ts"}' | bash ~/.claude/hooks/guard.sh; echo "exit=$?"   # 期待: exit=0
```

スクリプト単体が正しくても、settings.json への登録が効いているかは別問題。
可能なら実際に `.env` への書き込みを試みてブロックされることまで確認する。
確認できなければ**「未確認」と正直に伝える**。

---

## Phase 4. `~/.claude/settings.json` の permissions

グローバルには**「どのプロジェクトでも危険なもの」だけ**を入れる。
プロジェクト固有の deny は `/setup-project` の担当。

### deny（推奨・全プロジェクト共通）

```jsonc
"deny": [
  // 秘密情報の読み取り — 読めると転記される経路が生まれる
  "Read(**/.env)", "Read(**/.env.local)", "Read(**/.env.production)",
  "Read(**/secrets/**)", "Edit(**/secrets/**)",
  "Read(~/.ssh/**)", "Edit(~/.ssh/**)",

  // 自分のルールを書き換えさせない — ここが破られると他の deny が無意味になる
  "Edit(~/.claude/settings.json)", "Edit(~/.claude/hooks/**)",

  // 不可逆操作
  "Bash(git push --force*)", "Bash(git push -f*)", "Bash(git reset --hard*)"
]
```

### allow（推奨・摩擦の削減）

読み取り専用かつ冪等なものだけ。deny だけ書くと毎回聞かれる状態が残り、確認が形骸化する。

```jsonc
"allow": [
  "Bash(rg:*)", "Bash(ls:*)",
  "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)"
]
```

### 入れない判断

外部公開系（`gh pr merge` / `npm publish` / デプロイ）をグローバル deny に入れるかは
**ユーザーに聞く**。リリース作業を Claude Code でやる運用なら、
グローバルで塞ぐと毎回邪魔になる。プロジェクト単位のほうが適切なことが多い。

---

## Phase 5. 引き渡し

報告に必ず含める:

- **作ったファイル一覧**とバックアップの場所
- **動作確認の結果**（guard.sh が効いたか。未確認なら未確認と書く）
- **次にやること**: プロジェクトディレクトリで `/setup-project`
- **グローバルは薄く保つ**方針の再確認。手続きを足したくなったら
  プロジェクト側か skill へ、と伝える

---

## Gotchas

- **`~/.claude/settings.json` を丸ごと書き直さない。** 既存キー（`statusLine`、`enabledPlugins`、
  `extraKnownMarketplaces`、`theme` 等）を消すと全プロジェクトに影響する。
  必要なキーだけをマージする
- **バックアップを取ってから書く。** 影響範囲がユーザー全体なので、
  プロジェクト設定より慎重に扱う
- **hooks のネストを間違えない。** `{"matcher": ..., "command": ...}` の直書きは無効。
  `hooks` 配列に入れる
- **guard.sh は permissions の deny と重複してよい。** 役割が違う（deny はパターン、
  hook は条件分岐と保険）。片方だけにしない
- **このスキルは初回だけ。** 2回目以降は差分モードになるが、
  基本的には `/setup-project` のほうを使う
