# reference/ — 設計の教材置き場

このディレクトリは**キットの設計を作るための素材**を置く場所。**配布物には含まれない**
（`articles/` と `sources/` は `.gitignore` で除外済み。この README だけが追跡される）。

## 置き方

```
reference/
  articles/     記事を .md で保存する
  sources/      ソースコードを配布元ごとのサブディレクトリで置く
```

### articles/

1ファイル1記事。**先頭に出典を書く**:

```markdown
<!--
source: https://example.com/article-url
author: 著者名
fetched: 2026-08-19
-->

# 記事タイトル
...
```

出典を書く理由は2つ。(1) 後から一次情報に戻れる。(2) 生成したスキルの根拠を追える。

### sources/

配布元ごとにディレクトリを切る。zip で受け取ったものは展開して置く。

```
sources/
  masao-skills/        まさお氏配布の skills.zip 展開物
  someones-plugin/
```

## なぜファイルで置くのか

- 会話に貼ると流れて消えるが、ファイルなら何度でも参照できる
- 大量にあってもコンテキストを圧迫しない（必要箇所だけ grep / read できる）
- URL 直参照は取得失敗・ログイン壁のリスクがある

## 注意

他者の著作物をここに置くのは**設計の参照のため**。`.gitignore` で public repo から
除外しているので、**新しいファイルを追加したら `git status` で漏れていないか確認する**。
