# Edge-TTS

<p align="center">
<img src="./demo_app.png" alt="Edge-TTS" title="Edge-TTS" width="557"/>
</p>

Edge-TTS は、Microsoft Edge のテキスト読み上げ（TTS）サービスの Swift 実装です。このライブラリは開発者が Apple プラットフォームアプリケーションに高品質な音声合成機能を簡単に統合できるシンプルで使いやすい API インターフェースを提供します。

[English Documentation](README.md) | [中文文档](README_CN.md) | [한국어 문서](README_KR.md)

## 機能

### 多様な音声と言語

- 400 以上のニューラルネットワーク音声
- 100 以上の言語と地域バリアントをサポート
- 自然な音声合成効果

### 柔軟な音声制御

- 調整可能な発話速度 (-50% ～ +100%)
- ピッチ制御 (-50Hz ～ +50Hz)
- 音量制御 (-50% ～ +50%)
- 境界タイプ選択（文/単語）

### 豊富な出力オプション

- MP3 形式のエクスポートをサポート
- リアルタイム音声合成ストリーミング
- 非同期変換と再生
- オプションの JSON メタデータエクスポート
- オプションの SRT 字幕エクスポート
- クロスプラットフォームファイルエクスポート対応（iOS/macOS）

### 開発ツール

- クイックテストとバッチ処理用のコマンドラインツール
- ビジュアル設定用のネイティブ GUI アプリケーション
- 詳細な API ドキュメントと使用例

### クロスプラットフォーム互換性

- macOS 13.0+
- iOS/iPadOS 15.0+

## インストール

### Swift Package Manager

Package.swift ファイルに以下の依存関係を追加してください：

```swift
dependencies: [
    .package(url: "https://github.com/brewusinc/edge-tts.git", from: "1.0.0")
]
```

## クイックスタート

### 基本的な使用方法

```swift
import EdgeTTS

// TTSインスタンスの作成
let tts = EdgeTTS(config: Configure(
    voice: "ja-JP-NanamiNeural",
    rate: "+0%",
    pitch: "+0Hz",
    volume: "+0%",
    saveJSON: true,  // JSONメタデータエクスポートを有効化
    saveSRT: true,   // SRT字幕エクスポートを有効化
    boundaryType: .sentence  // 文境界を使用（単語境界の場合は.word）
))

// 非同期変換
Task {
    do {
        try await tts.ttsPromise(text: "こんにちは、世界", audioPath: "output.mp3")
        print("変換が完了しました")
    } catch {
        print("変換に失敗しました: \(error)")
    }
}
```

### コマンドラインツールの使用方法

コマンドラインツールには 2 つの主要コマンドがあります：`list` と `speak`。

#### 利用可能な音声の一覧表示

```bash
# すべての利用可能な音声を表示
edge-tts-cli list

# プロキシを使用して音声を表示
edge-tts-cli list --proxy http://host:port
```

#### テキストの音声変換

```bash
# 基本的な使用方法（直接テキスト）
edge-tts-cli speak --text "こんにちは、世界" --output hello.mp3

# ファイルからテキストを読み込む
edge-tts-cli speak --file input.txt --output hello.mp3

# 音声と言語を指定
edge-tts-cli speak --text "こんにちは、世界" --voice ja-JP-NanamiNeural --lang ja-JP --output hello.mp3

# 音声パラメータの調整
edge-tts-cli speak --text "こんにちは、世界" --rate +50% --pitch +10Hz --volume +20% --output hello.mp3

# JSONとSRTエクスポートを有効化
edge-tts-cli speak --text "こんにちは、世界" --save-json --save-srt --output hello.mp3

# 境界タイプの設定
edge-tts-cli speak --text "こんにちは、世界" --boundary word --output hello.mp3

# プロキシの使用
edge-tts-cli speak --text "こんにちは、世界" --proxy http://host:port --output hello.mp3
```

`speak` コマンドの利用可能なオプション：

- `--text`: 変換するテキスト
- `--file`: 入力テキストファイルのパス
- `--voice`: 使用する音声（デフォルト：ja-JP-NanamiNeural）
- `--lang`: 使用する言語（デフォルト：ja-JP）
- `--rate`: 発話速度（例：+0%、-10%）
- `--pitch`: ピッチ（例：+0Hz、-10Hz）
- `--volume`: 音量（例：+0%、-10%）
- `--boundary`: 境界タイプ（sentence または word、デフォルト：sentence）
- `--save-json`: タイミング情報を JSON として保存
- `--save-srt`: タイミング情報を SRT として保存
- `--proxy`: プロキシ URL（例：http://host:port）
- `--output`: 出力ファイル名（デフォルト：output.mp3）

### GUI アプリケーションの使用方法

1. Edge TTS Demo の最新バージョンをダウンロードしてインストール
2. アプリケーションを開き、変換したいテキストを入力
3. 希望の音声とパラメータ設定（速度、ピッチ、音量）を選択
4. 必要に応じて JSON/SRT エクスポートを有効化
5. 境界タイプ（文または単語）を選択
6. 「変換と再生」ボタンをクリックして合成音声を聴く
7. エクスポートボタンを使用してファイルを保存：
   - iOS：システム共有シートで柔軟なファイル処理
   - macOS：保存ダイアログで保存場所を選択

## エクスポート機能

### ファイルタイプ

- MP3：合成音声のオーディオファイル
- JSON：各文/単語のタイミングメタデータ
- SRT：タイムスタンプ付き字幕ファイル

### プラットフォーム固有のエクスポート

- iOS/iPadOS：
  - システム共有シート統合
  - 他のアプリへの共有
  - AirDrop サポート
  - ファイルアプリへの保存
- macOS：
  - ネイティブ保存ダイアログ
  - 保存場所の選択
  - ファイルタイプフィルタリング
  - 自動ファイル拡張子処理

## 一般的な音声

利用可能な音声のリストは以下の方法で取得できます：

```swift
let voices = try await tts.fetchVoices()
```

一般的な日本語音声：

- ja-JP-NanamiNeural (女性)
- ja-JP-KeitaNeural (男性)
- ja-JP-AoiNeural (女性)
- ja-JP-DaichiNeural (男性)
- ja-JP-ShioriNeural (女性)

## 貢献ガイド

以下を含むすべての形式の貢献を歓迎します：

- バグ報告と機能提案
- コードの改善
- ドキュメントの改善
- テストケースの追加

## ライセンス

このプロジェクトは MIT ライセンスの下で提供されています - 詳細は [LICENSE.txt](LICENSE.txt) をご覧ください。
