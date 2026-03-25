# ポン — 決まった、ポン。

> 電子契約・署名アプリ

[![TestFlight](https://img.shields.io/badge/TestFlight-Beta-blue)](https://testflight.apple.com/join/XyZdmPVt)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Open Source](https://img.shields.io/badge/Open%20Source-Enabler-E8A838)](https://enablerdao.com)

## Features

- PDF電子署名 — iPhoneから直接PDFに署名を追加
- 契約管理 — 作成した契約書を一元管理
- 送付済み/署名済みトラッキング — 契約のステータスをリアルタイムで把握
- レポート — 契約件数や署名状況の統計を可視化

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS | SwiftUI, SwiftData |
| PDF | PDFKit |
| Signature | PencilKit |

## Getting Started

```bash
git clone https://github.com/yukihamada/pon.git
cd pon/ios
xcodegen generate
xcodebuild -project Pon.xcodeproj -scheme Pon \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Contributing

PRs welcome!

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes
4. Push and create a PR

### コントリビューションポイント

Enablerエコシステムへの貢献はポイントとして記録されます。
将来的なガバナンス参加に活用される予定です。

## Security

- 全データはiPhoneのローカルに保存
- 外部サーバーへのデータ送信なし
- オープンソースでコードを検証可能

## License

MIT — 詳細は [LICENSE](LICENSE) を参照

## Links

- [TestFlight Beta](https://testflight.apple.com/join/XyZdmPVt)
- [Enabler](https://enablerdao.com)
- [pasha.run/pon](https://pasha.run/pon)

---

Built with AI. Tested with AI. Polished by humans.
