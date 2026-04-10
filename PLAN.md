# 実装計画: カスタム辞書機能

> この計画は Living Document です。実装中に Progress / Decision Log / Surprises を随時更新してください。

## ゴール

whisper-input に2層構造のカスタム辞書を追加する。
1. **Vocabulary** — Whisper の `--prompt` に語彙を注入し、固有名詞の認識精度を上げる
2. **Replacements** — 後処理で確定的な文字列置換を行い、既知の誤認識パターンを修正する

ユーザーはメニューバーから GUI で辞書を編集でき、JSON ファイルを直接触る必要がない。

## 検証方法

1. `open-wispr start` → メニューバーの「Edit Dictionary...」を開く
2. Vocabulary に「Souriant」を追加 → 保存 → 「スリアン」と発声 → 「Souriant」と認識される確率が上がる
3. Replacements に `苦闘点 → 句読点` を追加 → 保存 → 「苦闘点」と認識された場合に「句読点」に置換される
4. `open-wispr status` で辞書のエントリ数が表示される
5. `swift test` が全パス

## アーキテクチャ

```
dictionary.json
  ├── vocabulary: ["Souriant", "Claude", ...]
  └── replacements: [{ "from": "苦闘点", "to": "句読点" }, ...]

Transcriber.transcribe()
  └── --prompt に vocabulary を連結して渡す (Layer 1)

AppDelegate.handleRecordingStop()
  └── Whisper 出力 → Dictionary.applyReplacements() (Layer 2) → TextInserter

DictionaryWindow (NSWindow)
  └── メニューバーの「Edit Dictionary...」から開く GUI エディタ
```

## ファイルマップ

| ファイル | 操作 | 責務 |
|---|---|---|
| `Sources/OpenWisprLib/Dictionary.swift` | 新規 | 辞書データモデル + JSON 読み書き + 置換ロジック |
| `Sources/OpenWisprLib/DictionaryWindow.swift` | 新規 | 辞書編集 GUI (NSWindow) |
| `Sources/OpenWisprLib/Transcriber.swift` | 変更 | vocabulary を `--prompt` に注入 |
| `Sources/OpenWisprLib/AppDelegate.swift` | 変更 | 辞書読み込み + replacements 適用 |
| `Sources/OpenWisprLib/StatusBarController.swift` | 変更 | メニューに「Edit Dictionary...」追加 |
| `Sources/OpenWispr/main.swift` | 変更 | `status` に辞書情報追加 |
| `Tests/OpenWisprTests/DictionaryTests.swift` | 新規 | 辞書のユニットテスト |

## 実装ステップ

### Step 1: Dictionary データモデル

`Dictionary.swift` を新規作成。

```swift
public struct Dictionary: Codable {
    public var vocabulary: [String]
    public var replacements: [Replacement]

    public struct Replacement: Codable {
        public var from: String
        public var to: String
    }
}
```

責務:
- `~/.config/open-wispr/dictionary.json` の読み書き (`load()` / `save()`)
- `applyReplacements(_:)` — テキストに replacements を順次適用して返す
- `promptFragment()` — vocabulary を Whisper の prompt 用文字列に連結して返す
- ファイルが存在しない場合は空の辞書を返す（エラーにしない）

検証: `DictionaryTests.swift` で JSON パース、置換ロジック、空辞書のテストが通る
コミット: "feat: add Dictionary data model with vocabulary and replacements"

### Step 2: Transcriber に vocabulary 注入

`Transcriber.swift` を変更:
- `init` に `vocabulary: [String]` パラメータを追加
- `transcribe()` 内で `--prompt` 引数を組み立てる際、既存の日本語句読点ヒントの**末尾**に vocabulary を連結
  - 例: `--prompt "こんにちは。今日はいい天気ですね。はい、そうです！ Souriant, Claude, Anthropic"`
  - vocabulary が空なら現状と同じ動作

検証: vocabulary あり/なしで `--prompt` の組み立てが正しいことをログ出力で確認
コミット: "feat: inject vocabulary into whisper --prompt"

### Step 3: AppDelegate に辞書統合

`AppDelegate.swift` を変更:
- `setup()` で `Dictionary.load()` を呼び辞書を保持
- `Transcriber` 初期化時に `dictionary.vocabulary` を渡す
- `handleRecordingStop()` と `reprocess()` の後処理パイプラインで、spoken punctuation の**後**に `dictionary.applyReplacements()` を適用
- `applyConfigChange()` でも辞書をリロード

検証: dictionary.json に手動でエントリ追加 → 音声入力 → 置換が適用される
コミット: "feat: integrate dictionary into transcription pipeline"

### Step 4: 辞書編集 GUI (DictionaryWindow)

`DictionaryWindow.swift` を新規作成。NSWindow ベースの辞書エディタ。

**レイアウト**:
```
┌─ Dictionary ────────────────────────┐
│                                     │
│ Vocabulary                          │
│ ┌─────────────────────────────┐     │
│ │ Souriant                    │ [-] │
│ │ Claude                      │ [-] │
│ │ Anthropic                   │ [-] │
│ └─────────────────────────────┘     │
│ [+] Add word                        │
│                                     │
│ ─────────────────────────────────── │
│                                     │
│ Replacements                        │
│ ┌──────────────┬──────────────┐     │
│ │ From         │ To           │ [-] │
│ │ 苦闘点       │ 句読点       │ [-] │
│ │ スリアン     │ Souriant     │ [-] │
│ └──────────────┴──────────────┘     │
│ [+] Add replacement                 │
│                                     │
│                        [Save]       │
└─────────────────────────────────────┘
```

実装方針:
- `NSWindow` + `NSStackView` ベース（AppKit のみ、SwiftUI 不使用）
- 既存の `StatusBarController` のパターンに合わせる
- Save ボタンで `Dictionary.save()` → `AppDelegate.reloadConfig()` 相当の辞書リロードを発火
- ウィンドウはシングルトン（2重に開かない）

検証: メニューから開く → エントリ追加/削除 → Save → dictionary.json に反映される
コミット: "feat: add dictionary editor window"

### Step 5: メニューバーに「Edit Dictionary...」追加

`StatusBarController.swift` を変更:
- 「Reload Configuration」の上に「Edit Dictionary...」メニュー項目を追加
- クリックで `DictionaryWindow` を表示
- Save 後の辞書リロードコールバックを `AppDelegate` に接続

`main.swift` を変更:
- `cmdStatus()` に辞書のエントリ数を表示（`Vocabulary: 3 words, Replacements: 2 rules`）

検証: メニューバーから辞書を開いて編集 → Save → 次の音声入力に反映される
コミット: "feat: add Edit Dictionary menu item and status display"

### Step 6: テスト

`Tests/OpenWisprTests/DictionaryTests.swift` を新規作成:
- JSON デコード（正常系 / 空 / 部分的）
- `applyReplacements()` — 単一置換、複数置換、該当なし、空文字列
- `promptFragment()` — vocabulary あり/なし
- ファイル不在時のフォールバック

`scripts/test-install.sh` に追加:
- `open-wispr status` に Dictionary 行が含まれることを確認

検証: `swift test` && `bash scripts/test-install.sh` が全パス
コミット: "test: add dictionary unit tests and install test assertions"

### Step 7: コードレビュー

`/code-review` で CC code-reviewer + Codex CLI の2段階レビュー

---

## Progress

- [x] Step 1: Dictionary データモデル (2026-04-10)
- [x] Step 2: Transcriber に vocabulary 注入 (2026-04-10)
- [x] Step 3: AppDelegate に辞書統合 (2026-04-10)
- [x] Step 4: 辞書編集 GUI (DictionaryWindow) (2026-04-10)
- [x] Step 5: メニューバー統合 + status 表示 (2026-04-10)
- [x] Step 6: テスト — DictionaryTests.swift 作成済み、XCTest 環境なし (CommandLineTools only) のため `swift test` は実行不可 (2026-04-10)
- [x] Step 7: コードレビュー — 4件指摘、全修正済み (2026-04-10)

## Decision Log

- Decision: Swift stdlib との衝突を避けるため `Dictionary` ではなく `CustomDictionary` と命名
  Rationale: `Dictionary` は Swift の組み込み型。コンパイルは通るが曖昧さが生まれる
- Decision: 辞書ファイルは config.json とは別の dictionary.json に分離
  Rationale: 辞書エントリが増えても config が汚れない。SuperWhispr も分離方式

## Surprises & Discoveries

- XCTest が CommandLineTools 環境では使えず `swift test` が実行不可。既存テストも同様の状態
- SourceKit が新規ファイルの型 (`CustomDictionary`) を認識しないが、ビルドは通る（インデックス遅延）

## Outcomes & Retrospective

（完了時に記入）
