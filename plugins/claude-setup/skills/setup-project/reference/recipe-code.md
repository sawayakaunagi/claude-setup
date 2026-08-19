# レシピ — コード開発型

決定論的な検証手段（テスト・型・lint）が存在する前提で組む。
**その検証手段を CLAUDE.md に正しく書き、hook で自動化し、deny で守る**の3層。

---

## 1. CLAUDE.md

### 原則: 百科事典ではなく地図（→K-2.1）

巨大な指示ファイルはタスク本体を押し出し、古いルールを混入させる。
**入口を短くし、詳細はポインタ先へ**。目安は 50 行以内で立ち上げ、必要になったら育てる。

書かないもの（→E-2 / →A-3）:
- Claude が既に知っていること（「React はコンポーネントベース」「DRY を守る」等）
- 一般論のコーディング規約。判断基準は **「Would Claude do this anyway if it were smart enough?」**
  が Yes なら書かない
- 実在しないコマンドやディレクトリ（→D-2 嘘を教えるのが最悪。未確認なら書かない）

### テンプレート

```markdown
# {プロジェクト名}

{1〜2文。何のためのリポジトリか}

## Stack

- 言語: {検出値。例 TypeScript 5.x}
- ランタイム: {Node 24 / Python 3.13 / Go 1.23}
- パッケージマネージャ: {pnpm / uv / go mod}
- テスト: {Vitest}（{Jest} ではない）
- Lint / Format: {Biome}

## Commands

| 目的 | コマンド |
|---|---|
| テスト | `{pnpm test}` |
| 単体で1ファイル | `{pnpm vitest run path/to/file.test.ts}` |
| 型チェック | `{pnpm tsc --noEmit}` |
| Lint | `{pnpm biome check .}` |
| 開発サーバ | `{pnpm dev}` |

## Architecture

{2〜4行。ディレクトリの役割だけ。ファイル一覧は書かない}

- `src/` — {}
- `tests/` — {}

## 完了の定義

{テスト・型・lint が緑}であることをもって完了とする。
「実装した」だけでは完了ではない。

## Gotchas

{このリポジトリ固有の落とし穴。無ければセクションごと削る}
```

### 埋め方

| 欄 | 取得元 |
|---|---|
| 言語・ランタイム | `package.json` の `engines`、`.nvmrc`、`pyproject.toml` の `requires-python`、`go.mod` |
| パッケージマネージャ | lockfile（`pnpm-lock.yaml` / `uv.lock` / `package-lock.json`）**推測しない** |
| テスト FW | devDependencies / `pyproject.toml` の依存。設定ファイル（`vitest.config.*`）でも確認 |
| Commands | `package.json` の `scripts` を**実際に読んで**書き写す |

**`(TypeScript プロジェクトなのに JavaScript で書く)` を防ぐのがこのセクションの主目的**（→C-6 訓練データの断崖）。
スタックを明示しないと訓練データの頻度で推測される。「Jest ではない」のような**否定形の明示**が効く。

コマンドは**検出できたものだけ書く**。`scripts` に無いコマンドを推測で書くと、
以後のセッションが存在しないコマンドを叩き続ける（→D-2）。

---

## 2. settings.json

`settings-catalog.md` から以下を採用する。

| # | 部品 | 採否 |
|---|---|---|
| 1 | テスト・lint 設定の保護 | **必須**（実装と検証が同一セッションで動くため） |
| 2 | 自分のルールの保護 | **必須** |
| 3 | 不可逆操作 | **必須**（git リポジトリなら） |
| 4 | 外部影響 | インタビューで該当ありなら |
| 5 | 秘密情報 | `.env*` か `secrets/` が存在するなら |
| 6 | allow（read-only コマンド） | **推奨**。検出した PM に合わせる |
| 7 | PostToolUse フォーマッタ | フォーマッタを検出できたら |
| 8 | PreToolUse ガード | `~/.claude/hooks/guard.sh` が無い場合のみ |

### 生成例（Node + Vitest + Biome）

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(pnpm test:*)",
      "Bash(pnpm run lint:*)",
      "Bash(pnpm tsc --noEmit*)",
      "Bash(rg:*)", "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)"
    ],
    "deny": [
      // 評価基準を守る: テストを書き換えれば緑になるため
      "Edit(**/*.test.*)", "Edit(**/*.spec.*)", "Edit(**/e2e/**)",
      "Edit(tsconfig.json)", "Edit(biome.json)",
      // 権限設定自体を守る: ここが破られると他の deny が無意味になる
      "Edit(.claude/settings.json)", "Edit(.claude/settings.local.json)",
      // 不可逆操作
      "Bash(git push --force*)", "Bash(git push -f*)", "Bash(git reset --hard*)"
    ]
  },
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
}
```

---

## 3. スキル — 初回は作らない

**立ち上げ時点では「何が繰り返されるか」がまだ分からない。**
存在しない繰り返しを先回りしてスキル化すると、使われないスキルの description が
全セッションのコンテキストを食う（→C-1）。

初回に作るのは**ゼロ個**が既定。CLAUDE.md に次の1行だけ残す:

```markdown
## Skills
まだ無し。同じ手順を3回繰り返したら `/design-skill` でスキル化を検討する。
```

例外: インタビューで「毎回やる決まった手順がある」と明示された場合のみ、その1つを作る。

---

## 4. 推奨する連携（Phase 4 で提示）

| 連携 | いつ勧めるか |
|---|---|
| TDD ループ（`red-test` → `delegate-implement` → `verify-test`） | 仕様が `REQUIREMENTS.md` 等で先に書ける案件。JS/Jest 前提のものは前提の一致を確認してから |
| `akapen`（作る前に1案を人に見せる） | UI・設計方針など、作ってから直すと高くつくもの |
| `bestofn` | 実装方針が割れていて、複数案を比べたいとき |
| CI（GitHub Actions） | 既に `.github/workflows/` があるなら CLAUDE.md にコマンドを転記。無いなら初回は作らない |

**押し付けない。** 検出して「あります、使いますか」と示すだけにする。

---

## 5. 生成後に必ず伝えること

1. **hook が本当に効いているか**は、実際に1ファイル編集して確かめないと分からない
   （ネストを間違えると静かに無視される）
2. deny に入れたものは**後から緩められる**。きつすぎたら言ってほしい
3. CLAUDE.md は育てる文書。今書いたのは骨格で、Gotchas は運用しながら足す
