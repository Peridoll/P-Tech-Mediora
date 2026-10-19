# P-Tech Mediora

P-Tech Mediora は、FiveMロールプレイサーバー向けの医療システム群です。

診察・治療・搬送・NPC患者・医療物資調達・製薬・請求・精算を、必要なものだけ導入できる独立リソースとして開発しています。リソース名は ptech_mediora_<module> を使用します。

## 現在の状態

開発・検証中です。実機での結合試験が完了していない機能を含むため、本番環境への導入前には確認が必要です。

現在のリソースは次の7つです。

| リソース | 役割 |
|---|---|
| ptech_mediora_medical | 診察、診断書、治療・請求の基盤 |
| ptech_mediora_escort | 行動不能者の搬送と車両移送 |
| ptech_mediora_patients | NPC患者と医療ミッション |
| ptech_mediora_procurement | 医療物資の調達 |
| ptech_mediora_pharmacy | 医療品の製薬 |
| ptech_mediora_billing | 医療請求の作成 |
| ptech_mediora_settlement | 調達レシートの精算管理 |

開発中の仕様、実装状況、試験結果は [DEVELOPMENT.md](DEVELOPMENT.md) にまとめています。
