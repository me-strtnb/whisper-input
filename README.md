# whisper-input

ローカル完結の音声入力ツール。fn (Globe) キー長押し → 喋る → 離す → テキストが自動入力される。
音声データは一切外部に送信されない。

[open-wispr](https://github.com/human37/open-wispr) の fork。

## セットアップ

### 前提

- macOS (Apple Silicon)
- Homebrew

### インストール

```bash
# 1. whisper-cpp をインストール
brew install whisper-cpp

# 2. clone & build
git clone https://github.com/me-strtnb/whisper-input.git
cd whisper-input
swift build -c release

# 3. 初回起動 (モデルダウンロード + 権限設定)
.build/release/open-wispr start
```

初回起動時に:
- Accessibility 権限のダイアログ → 許可
- Microphone 権限のダイアログ → 許可
- Whisper モデルのダウンロード (~1.6GB)

### Globe (fn) キーの設定

Globe キーで絵文字ピッカーが開く場合:
**System Settings → Keyboard → "Press Globe key to" → "Do Nothing"**

### バックグラウンド実行

```bash
nohup ~/whisper-input/.build/release/open-wispr start > ~/.config/open-wispr/daemon.log 2>&1 &
disown
```

### ログイン時の自動起動

```bash
# ランチャースクリプトを作成
cat > ~/.config/open-wispr/launch.sh << 'EOF'
#!/bin/bash
nohup ~/whisper-input/.build/release/open-wispr start > ~/.config/open-wispr/daemon.log 2>&1 &
disown
EOF
chmod +x ~/.config/open-wispr/launch.sh

# ログイン項目に登録
osascript -e 'tell application "System Events" to make login item at end with properties {path:"'$HOME'/.config/open-wispr/launch.sh", hidden:true}'
```

## 設定

`~/.config/open-wispr/config.json`:

```json
{
  "hotkey": { "keyCode": 63, "modifiers": [] },
  "modelSize": "large-v3-turbo",
  "language": "ja",
  "spokenPunctuation": false,
  "toggleMode": false,
  "maxRecordings": 0
}
```

| 項目 | デフォルト | 説明 |
|---|---|---|
| `modelSize` | `large-v3-turbo` | Whisper モデル。日本語なら `large-v3-turbo` 推奨 |
| `language` | `ja` | 言語コード |
| `hotkey.keyCode` | `63` | Globe/fn キー |
| `toggleMode` | `false` | `true` で押す→喋る→押すのトグル式 |

## upstream からの変更点

- 日本語句読点: `--prompt` で句読点付きテキストを whisper に渡し、出力スタイルを誘導
- フローティングインジケーター: 画面下部にガラス風ピル型の録音インジケーター (実音声レベル駆動の波形)
- マルチモニター対応: マウスカーソルのあるスクリーンにインジケーター表示
- whisper-cli フラグ調整: `-np` 追加

## 操作

- **デーモン停止**: `pkill -f open-wispr`
- **デーモン再起動**: `~/.config/open-wispr/launch.sh`
- **ログ確認**: `cat ~/.config/open-wispr/daemon.log`
- **設定リロード**: メニューバーアイコン → Reload Configuration

## License

MIT (upstream: [human37/open-wispr](https://github.com/human37/open-wispr))
