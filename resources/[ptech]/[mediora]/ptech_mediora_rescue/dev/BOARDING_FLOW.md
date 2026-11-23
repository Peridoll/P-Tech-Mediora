# Rescue ヘリ読込・搭乗の切り分け

`ptech_mediora_rescue` は、モデル読込・ヘリ生成・プレイヤーの助手席配置だけを確認する独立リソースです。必要なのは `ox_lib` とOneSyncです。操縦士NPC、職業・死亡判定、8分待機、R長押し、病院への飛行、EMS通知は入れていません。生存中・ダウン中それぞれで試せます。HPや死亡状態は変更しません。

## 最初の確認

元のRescueをモデル読込・生成・搭乗だけの構成へ切り替えています。サーバーコンソールで再起動します。

```text
refresh
restart ptech_mediora_rescue
```

ゲーム内で車外に出て実行します。

```text
/rescueheli local
```

`local` は手元だけに見えるヘリを生成します。`buzzard2` を明示的に読んでから5m上に生成し、助手席（seat 0）へ配置します。機体は固定したまま残ります。搭乗状態を2秒維持できれば「搭乗状態を2秒維持できました」と通知します。

今回の到達点はここまでです。飛行・自動削除は行いません。座席から外れた場合は元の位置へ戻し、機体を残して `SEAT_LOST` を記録します。

## 片付けとサーバー生成との比較

```text
/rescueheli clear
/rescueheli server
```

`clear` は、検証機に乗っている本人を元の位置へ戻して機体を削除します。別の車両に乗った場合や外部処理ですでに遠くへ移動した場合は、その移動を上書きしません。

`server` は同じモデル読込後にサーバーへ生成を要求します。通常Rescueと同じ `CreateVehicleServerSetter` を使い、ネットワークID、所有者、バケット、生成座標をF8へ記録します。モデル読込と搭乗処理は `local` と共通です。これで `local` は成功するが `server` は届かないケースを比較できます。`local` の成功だけではサーバー配信が直ったとは判定しません。

## ログの見方

F8の `[rescue_boarding]` を確認します。文字化けを避けるため段階名は英数字です。

| 段階 | 確認できたこと |
|---|---|
| `MODEL_OK` | ヘリモデルの読込完了 |
| `SERVER_SNAPSHOT` | サーバー側の実体・所有者・バケット・座標（serverモード） |
| `ENTITY_OK` | クライアントにヘリの実体が存在する |
| `BOARD_OK` | プレイヤーの車両が検証ヘリになった |
| `BOARD_STABLE` | 搭乗状態を2秒維持した |
| `BOARD_FAIL` | 配置しても搭乗が成立しなかった |
| `SEAT_LOST` | 機体はあるがプレイヤーが座席から外れた |
| `ENTITY_MISSING` / `ENTITY_LOST` | 機体が届かない、または搭乗後に消えた |

失敗時も調査できるよう、検証機は `clear` するまで残します。試行を重ねる場合は毎回 `clear` を実行してください。切断・リソース停止時にも後片付けします。

## 権限・設定

`command.rescueheli` または既存の `command.rescueskip` 権限があれば開始できます。既存の時短コマンドを使用できる管理者は追加の権限設定は不要です。個別に付与する場合：

```cfg
add_ace group.admin command.rescueheli allow
```

Coreの候補・`/mediorahelp` にも登録しています（`command.rescueskip` 権限とRescueの起動時）。ヘルプ設定を反映する場合はCoreを再起動してください。モデル、生成高さ、読込・搭乗確認の期限は `main/shared/boarding.lua` で変更できます。モデル名は元の `config.lua` の `Config.Helicopter.Model` を使用します。

自動テストは`dev/tests/test_probe.py` に置いています。FiveMの物理・ネットワーク配信とWasabiとの併用は実機で確認してください。

従来のR長押し・待機短縮・病院搬送は一時停止しています。`/rescueskip` は検証コマンドへの案内を表示します。元の搬送コードは `main/client/client.lua` と `main/server/server.lua` に残し、manifestから起動対象を外しました。設計メモは `dev/FULL_FLOW.md` に保管しています。

## 起動・コマンド受付の確認

サーバー起動時に `[rescue_boarding] SERVER_READY build=boarding-input-v2`、F8に `[rescue_boarding] CLIENT_READY build=boarding-input-v2` が出ます。表示されなければ新しい起動ファイルが読み込まれていません。`fxmanifest.lua` と `main/shared/boarding.lua`、`main/client/boarding.lua`、`main/server/boarding.lua` の反映を確認し、サーバーコンソールで `refresh` の後にRescueを再起動してください。

チャットでは `/rescueheli local`、F8では `rescueheli local` を実行します。入力時に `COMMAND`、サーバー受付で `SERVER_ACK`、生成開始指示で `START_RECEIVED` を記録します。応答がなければ5秒で `NO_SERVER_REPLY` を通知します。権限確認は引き続きサーバー側で行います。
