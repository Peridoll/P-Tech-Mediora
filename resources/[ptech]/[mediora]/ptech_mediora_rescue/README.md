# Rescue：COREゲージとNPCヘリの搭乗・削除を検証

現在は0.5.2。死亡・瀕死を検知してから初期値5秒待機し、Rを3秒長押しすると現在地の20m上へ操縦士NPC付きのヘリを生成し、プレイヤーを助手席へ配置します。NPCへ上空での操縦指示を出し、搭乗確認から5秒後、プレイヤーを元の位置に戻してヘリとNPCを削除します。HPと死亡状態は変更しません。

## COREとの接続修正

CORE 0.2.3は、NUI準備完了前に受理したパネルを保持し、準備完了時・画面再読み込み時に再送します。
NUIからの初回接続失敗も300ms後に再試行します。今回の表示修正ではCOREも更新し、次の順で再起動します。

```text
refresh
ensure ptech_mediora_core
ensure ptech_mediora_rescue
```

F8に `[ptech_mediora_core] action panel READY build=panel-sync-v1 replayed=...` が出れば、
COREの画面からLuaへの接続が完了しています。Rescueの `LOAD` / `DOWN` / `PANEL_REGISTERED` と区別して確認します。

## 反映と確認

サーバーコンソールで実行します。COREサイドバーへの接続に `ptech_mediora_core`、キー入力に `ox_lib` を使用します。

```text
refresh
ensure ptech_mediora_rescue
```

1. 死亡・瀕死になるとCOREサイドバーを自動展開し、「緊急離脱」に `使用可能まで 5:00` が表示されます。
2. 待機終了後にRを3秒長押しします。従来のCOREゲージに長押し進捗を表示します。
3. ヘリの操縦席（-1）にNPC、助手席（0）に本人を配置します。
4. 搭乗確認後は削除までの秒数を表示し、5秒後に地上へ戻してヘリとNPCを削除します。

Rを途中で離すと長押し進捗だけをリセットします。待機時間は戻りません。押し続けても連続でヘリを生成しません。もう一度試す場合はRを離して押し直してください。再試行時に同じ死亡状態の5秒待機をやり直す必要はありません。死亡状態の終了・ped変更・リソース再起動では待機時間を初期化します。

FiveMのキー設定を変更済みの場合、実際の割当キーを使います。COREの表示キーもその割当に追従します。モデル読込・生成・搭乗が失敗した場合は通知とF8ログを出し、生成済みのヘリとNPCを片付けます。

## 現在有効な設定

`config.lua` の以下を使用します。設定変更後はRescueを再起動してください。

| 設定 | 初期値 | 意味 |
|---|---|---|
| `Config.Countdown` | `5` | 死亡検知から長押し可能になるまでの秒数 |
| `Config.HoldDuration` | `3.0` | 長押し秒数 |
| `Config.Key` | `'R'` | 初期キー |
| `Config.SpawnTimeout` | `5000` | モデル読込・実体生成の各タイムアウト（ms） |
| `Config.Helicopter.Model` | `'buzzard2'` | ヘリのモデル |
| `Config.Helicopter.Pilot` | `'s_m_m_pilot_02'` | 操縦士NPCのモデル |
| `Config.Helicopter.HoverOffset` | `20.0` | 現在地からの生成高さ（m） |
| `Config.Helicopter.PassengerSeat` | `0` | プレイヤーの座席 |
| `Config.Helicopter.TestDuration` | `5.0` | 搭乗確認から削除までの秒数 |

## 調査用ログ

F8の `[rescue_pickup]` を確認します。待機中と待機終了後もパネルを展開したまま表示します。死亡状態が終了すると、一時展開する前のサイドバー状態へ戻します。

| ログ | 確認する段階 |
|---|---|
| `LOAD build=entry-v3 file=main/client/client.lua` | クライアントファイルの読込開始 |
| `READY build=entry-v3` | 現行コード・設定の起動。countdown=5も確認 |
| `DOWN` | 死亡判定に入り、待機時間の計測開始 |
| `PANEL_REGISTERED` | COREがパネル登録を受理した |
| `PANEL_FAILED` / `PANEL_UNAVAILABLE` | COREのAPI失敗・未起動 |
| `START` | 長押し完了・生成処理開始 |
| `MODEL_OK` | ヘリとNPCのモデル読込完了 |
| `PILOT_OK` | NPCが操縦席にいる |
| `BOARD_OK` | 本人が助手席に搭乗し、5秒の計測開始 |
| `CLEANUP COMPLETE` | 元の位置への復帰とヘリ・NPC削除完了 |
| `FAIL` | 読込・生成・搭乗・搭乗維持での失敗理由 |

## 今回も保留している機能

ヘリとNPCは本人のクライアントだけに生成します。他プレイヤーとの共有・サーバーのネットワークID取得は行いません。5秒間はNPCへホバリング位置への操縦を指示し、機体は固定しません。機体の衝突と被ダメージを無効化し、搭乗・操縦・削除の検証に絞っています。

病院への飛行、EMS通知、職業・勤務条件、サーバーの要請処理、`rescueheli` / `rescueskip` は引き続き起動しません。旧コードはmanifestでコメントアウトしています。前段階の単純な上空テレポートは `main/client/teleport.lua` に保存しています。

NPCの操縦にはCfxの [TaskHeliMission](https://github.com/citizenfx/natives/blob/master/TASK/TaskHeliMission.md) を使用します。Python/Luaのモック試験とLua構文検証を実施しますが、実際のFiveM内での動作確認は別途必要です。

表示されない場合は、`main/client/client.lua`・`config.lua`・`fxmanifest.lua`が反映されているか確認します。`LOAD` 自体が出ない場合、死亡判定へ入る前のファイル読込・配布段階を調べます。

0.5.2では、実行入口を既存の追跡済み `main/client/client.lua` に統一しました。実行に必要なRescue内のファイルは `fxmanifest.lua`、`config.lua`、`main/client/client.lua` の3つです。旧搬送実装は `dev/legacy/full_flow_client.lua` にそのまま保存し、0.5.1の `main/client/pickup.lua` は起動しません。
