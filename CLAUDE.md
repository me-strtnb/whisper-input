# CLAUDE.md — whisper-input

## What is this

open-wispr の fork。ローカル完結の macOS 音声入力ツール。
fn (Globe) 長押し → 喋る → 離す → whisper.cpp で文字起こし → カーソル位置に自動ペースト。

## Architecture

Swift Package (swift-tools-version 5.9)。外部 SPM 依存ゼロ。Apple フレームワークのみ。

```
Sources/
  OpenWispr/main.swift          — CLI エントリポイント
  OpenWisprLib/
    AppDelegate.swift           — 中央オーケストレーション (起動, 録音, 文字起こし, ペースト)
    HotkeyManager.swift         — NSEvent でグローバルキー検知 (fn/Globe 含む)
    AudioRecorder.swift         — AVAudioEngine で 16kHz mono WAV 録音 + 音量レベルコールバック
    Transcriber.swift           — whisper-cli をサブプロセスで実行
    TextInserter.swift          — クリップボード退避 → テキスト書込 → CGEvent で Cmd+V → クリップボード復元
    FloatingIndicator.swift     — 画面下部のフローティング録音インジケーター (ガラス風ピル + 波形)
    StatusBarController.swift   — メニューバーアイコン + メニュー
    Config.swift                — ~/.config/open-wispr/config.json の読み書き
    ModelDownloader.swift       — HuggingFace からモデル DL (唯一のネットワーク通信)
    Permissions.swift           — Accessibility / Microphone 権限チェック
    AudioDeviceManager.swift    — 入力デバイス列挙
    RecordingStore.swift        — 録音ファイル管理
    TextPostProcessor.swift     — spoken punctuation の変換 (英語向け)
    KeyCodes.swift              — キーコード名前解決
    Version.swift               — バージョン定数
```

## Key flows

### 録音 → 文字起こし → ペースト
1. `HotkeyManager` が fn keyDown を検知 → `AppDelegate.handleRecordingStart()`
2. `AudioRecorder.startRecording()` — AVAudioEngine で 16kHz mono WAV 書き出し + `onAudioLevel` コールバック
3. `FloatingIndicator.show(.recording)` — 画面下部にインジケーター表示
4. fn keyUp → `AppDelegate.handleRecordingStop()`
5. `Transcriber.transcribe()` — whisper-cli サブプロセス実行
6. `TextInserter.insert()` — クリップボード退避 → paste → 100ms 後にクリップボード復元
7. `FloatingIndicator.hide()`

### 日本語句読点
`Transcriber.swift` で言語が `ja` の場合、`--prompt "こんにちは。今日はいい天気ですね。はい、そうです！"` を追加。
whisper が句読点付きの出力スタイルに誘導される。

## Build & Run

```bash
swift build -c release
.build/release/open-wispr start
```

## Config

`~/.config/open-wispr/config.json` — 変更後はメニューバーから Reload Configuration。

## Upstream

fork 元: https://github.com/human37/open-wispr (MIT)
upstream の変更を取り込む場合: `git fetch upstream && git merge upstream/main`

## 今後の課題

- カスタム辞書 (誤変換修正: 「苦闘点→句読点」等)
- アプリ名・バンドル ID のリネーム
- モデル事前同梱 (ModelDownloader バイパス)
