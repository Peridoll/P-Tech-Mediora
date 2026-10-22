# P-Tech Mediora

P-Tech Mediora は、FiveMロールプレイサーバー向けの医療システム群です。

診察・治療・搬送・NPC患者・医療物資調達・製薬・請求・精算を、必要なものだけ導入できる独立リソースとして開発しています。リソース名は ptech_mediora_<module> を使用します。

## 現在の状態

開発・検証中です。実機での結合試験が完了していない機能を含むため、本番環境への導入前には確認が必要です。

現在のリソースは次の9つです。

| リソース | 役割 |
|---|---|
| ptech_mediora_medical | 診察とサーバー内の一時カルテ |
| ptech_mediora_manager | EMSタブレットのホームとカルテ閲覧 |
| ptech_mediora_escort | 行動不能者の搬送と車両移送 |
| ptech_mediora_marine | EMS用フィンと死亡後に任意で使える緊急浮上装置 |
| ptech_mediora_patients | NPC患者と医療ミッション |
| ptech_mediora_procurement | 医療物資の調達 |
| ptech_mediora_pharmacy | 医療品の製薬 |
| ptech_mediora_billing | 医療請求の作成 |
| ptech_mediora_settlement | 調達レシートの精算管理 |

開発中の仕様、実装状況、試験結果は [DEVELOPMENT.md](DEVELOPMENT.md) にまとめています。

Marineは既存のダイビングギアを変更しません。フィン用外観モデルは未同梱のため、初期設定では泳速だけを変更します。緊急浮上装置はアイテム不要で全員が使え、死亡から180秒後に水中／水面にいる本人だけがF長押しで起動できます。死亡状態を維持して緩やかに浮上し、Escort搬送または蘇生まで海面で水平位置を保ちます。発動中はGTA標準の救命浮輪を対象へローカル表示します。FiveM実機での併用・浮上・浮輪位置は未検証です。
