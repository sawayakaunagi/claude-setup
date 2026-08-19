# claude-setup

新しいプロジェクトに **Claude Code のハーネスを一括で敷く**ためのプラグイン。

`CLAUDE.md`・`.claude/settings.json`（permissions と hooks）・必要な連携を、
**そのプロジェクトの性質に合わせて**生成します。テンプレートをコピーするのではなく、
プロジェクトを見て判定してから作るので、使わない設定が積み上がりません。

Claude Code を**これから使い始める人**が最初に入れることを想定しています。

---

## インストール

```
/plugin marketplace add sawayakaunagi/claude-setup
/plugin install claude-setup
```

### ⚠️ このあと Claude Code を再起動してください

**再起動するまでスキルは呼べません。** `/plugin list` に `enabled` と出ていても、
そのセッションでは `Unknown skill: setup-project` になります。
「インストール成功」は「使える」の証拠ではありません。ここが一番よく詰まります。

---

## 使い方

### 1. 最初の一度だけ — グローバル設定

```
/setup-global
```

`~/.claude` を初期化します。

- `~/.claude/CLAUDE.md` — 全プロジェクト共通の薄い指示書
- `~/.claude/hooks/guard.sh` — `.env` や秘密鍵への書き込みを止める hook
- `~/.claude/settings.json` — 推奨 permissions（**既存の設定は上書きしません**）

### 2. プロジェクトごと

プロジェクトのディレクトリで:

```
/setup-project
```

やること:

1. プロジェクトを見て**種別を判定**し、確認を取る
2. 最大4問だけ質問する
3. `CLAUDE.md` → hooks → `settings.json` の順に生成する
4. 使えそうな連携を**提示だけ**する（勝手に入れません）
5. hook が本当に効いているか確認して報告する

既に `CLAUDE.md` がある場合は**補強モード**になり、上書きせず差分だけ提案します。

### 3. あとから — スキルを作るべきか迷ったとき

```
/design-skill
```

「スキルにすべきか、hook にすべきか、CLAUDE.md の1行で足りるか」から判断します。
**「作らない」という結論もよく出ます。**

---

## 何が生成されるか

種別によって中身が変わります。

### コード開発型（`package.json` / `pyproject.toml` / `go.mod` 等がある）

| | 内容 |
|---|---|
| `CLAUDE.md` | スタック宣言・実際に動くコマンド表・アーキテクチャ・完了の定義 |
| deny | テストと lint 設定の保護、`.claude/settings.json` の保護、不可逆な git 操作 |
| allow | 検出したパッケージマネージャの読み取り専用コマンド（確認プロンプトの削減） |
| hook | `PostToolUse` で検出したフォーマッタを自動実行 |

**テストを書き換えれば緑になる**ので、そこを物理的に閉じるのが要点です。

### 文書・ワークフロー型（記事・SNS・レポート・データ整形）

| | 内容 |
|---|---|
| `CLAUDE.md` | 成果物の定義・想定読者・素材の在り処・文体・外部由来テキストの扱い |
| `evaluation.md` | **評価軸の外部化**。テストの代わりに合否を決める文書 |
| deny | `evaluation.md` と素材ディレクトリの保護 |
| hook | 文字数・禁止語・textlint など、**機械で判定できる部分**の自動チェック |

テストが無い代わりに、**評価軸を文書にして守ります**。
機械で判定できるものは hook に落とし、LLM 採点はそれ以外だけに使います。

---

## SessionStart の案内について

`CLAUDE.md` も `.claude/settings.json` も無いディレクトリでセッションを開くと、
**1行だけ** `/setup-project` を案内します。

- 同じディレクトリでは1回しか出ません
- ハーネスがあるディレクトリでは出ません
- 止めるには環境変数 `CLAUDE_SETUP_NO_NUDGE=1`

---

## `audit-harness` との関係

このキットは**生成**、`audit-harness` は**診断**を担当します。
両者は同じ設計原則の語彙（`agent-essence` の C / T / K / V / S / E）を共有しているので、
`/setup-project` で作った直後にハーネス診断をかけると、そのまま答え合わせになります。

`audit-harness` は本キットには含まれていません（配布元が別）。持っていなくても
`/setup-project` は単体で動きます。

---

## 動作要件

- Claude Code
- bash（生成される hook スクリプト用。macOS / Linux 標準のもので動きます）
- 任意: `rg`、プロジェクトのフォーマッタ（無くても hook は静かに素通りします）

Windows は未検証です。

---

## 設計方針

- **配るのは生成ロジック、落ちるのは生成物。** テンプレートを配ると陳腐化し、
  ローカルの古い版がグローバルを上書きする事故が起きます
- **既存ファイルを上書きしない。** 補強モードは常に差分提案です
- **既定は「足さない」。** 連携もスキルも、必要になってから足すほうが常に安い
- **推測で書かない。** 検出できなかったコマンドやパスは書きません。
  嘘の前提は以後のセッションが信じ続けます

---

## 開発（このリポジトリを直す人向け）

ローカルの作業ツリーを marketplace として登録できます。

```bash
claude plugin marketplace add /path/to/claude-setup
claude plugin install claude-setup@claude-setup
```

### ⚠️ インストールは作業ツリーへのリンクではなく「コピー」

`~/.claude/plugins/cache/claude-setup/claude-setup/<version>/` にコピーされます。
**ソースを編集しても、そのままでは反映されません。**

```bash
claude plugin update claude-setup@claude-setup   # → そのあと再起動
```

### 変更したら通すもの

```bash
claude plugin validate ./plugins/claude-setup   # plugin.json
claude plugin validate .                        # marketplace.json
claude plugin details claude-setup@claude-setup # スキル/hook が認識されたか・トークン費用
bash -n plugins/claude-setup/hooks/*.sh         # シェル構文
```

`details` の **Always-on** は全セッションに常時載る費用です。ここが膨らんでいたら
description を削るサインです（現状 ~403 tok）。

### hook を書くときの注意

hook は**素の bash** で走ります。対話シェルの alias / function は見えません。
特に **`rg` は環境によっては実体が無く**、Claude Code のシェル関数として提供されています。
チャット上の Bash では動くのに hook では動かないので、関門となる検査は `grep` / `sed` だけで書いてください。

---

## ライセンス

MIT。同梱物と参照物の帰属は [NOTICE.md](./NOTICE.md) を参照してください。
