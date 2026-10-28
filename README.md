# P-Tech Mediora

P-Tech Mediora は、FiveMロールプレイサーバー向けの医療システム群です。

診察・治療・搬送・NPC患者・医療物資調達・製薬・請求・精算を、必要なものだけ導入できる独立リソースとして開発しています。リソース名は ptech_mediora_<module> を使用します。

## 現在の状態

開発・検証中です。実機での結合試験が完了していない機能を含むため、本番環境への導入前には確認が必要です。

現在のリソースは次の9つです。

| リソース | 役割 |
|---|---|
| ptech_mediora_medical | 診察とサーバー内の一時カルテ |
| ptech_mediora_marine | 水中でダウンしたプレイヤー向けの緊急浮上装置 |
| ptech_mediora_manager | EMSタブレットのホームとカルテ閲覧 |
| ptech_mediora_escort | 行動不能者の搬送と車両移送 |
| ptech_mediora_patients | NPC患者と医療ミッション |
| ptech_mediora_procurement | 医療物資の調達 |
| ptech_mediora_pharmacy | 医療品の製薬 |
| ptech_mediora_billing | 医療請求の作成 |
| ptech_mediora_settlement | 調達レシートの精算管理 |

開発中の仕様、実装状況、試験結果は [DEVELOPMENT.md](DEVELOPMENT.md) にまとめています。

Marineは緊急浮上装置のみを提供します。全プレイヤーが使え、水中で死亡または瀕死になってから180秒後にFを1秒長押しすると、死亡状態を維持したまま緩やかに水面へ浮上します。水中の車内で発動した場合は、車両を動かさず本人だけを車外へ出して浮上させます。上昇路を地形に塞がれた場合は近くの通路を探し、見つからなければ浮上を停止して救助を待ちます。FiveM実機での浮上動作は未検証です。
