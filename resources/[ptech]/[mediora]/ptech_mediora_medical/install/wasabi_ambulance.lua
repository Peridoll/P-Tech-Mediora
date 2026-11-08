--[=[
【手動導入】このファイルは fxmanifest.lua に登録しない。

1. 蘇生時の空腹・渇き・ストレスの自動回復を止める
   導入先: wasabi_ambulance/game/client/client.lua
   wasabi_ambulance:revivePlayer と wasabi_ambulance:revive の各 QB 分岐で、
   下記2行をコメントアウトする。wasabi_bridge:onPlayerSpawn は残す。

   TriggerServerEvent('hospital:server:resetHungerThirst')
   TriggerServerEvent('hud:server:RelieveStress', 100)

   wasabi_ambulance:heal は別処理なので、今回の変更には含めない。

2. Medical の新しい負傷判定を使う場合は Wasabi の Live Injury を停止する
   導入先: wasabi_ambulance/game/configuration/config.lua
   既存の同名設定を変更する。末尾への重複追記はしない。

   Config.EnableLiveInjury = false
   Config.InjuryNotification = false
   Config.BlackoutEffect = false
   Config.DisableNoJumpInjury = true

   この設定は負傷処理の重複を防ぐためのもの。死亡・瀕死・蘇生は Wasabi が担当する。

Wasabi側の従来の薬を継続使用する場合、それだけではMedicalの蓄積値は減らない。
下のサーバーexportを、回復に成功した処理から1使用につき1回呼ぶ。
exports.ptech_mediora_medical:recordMedication(patientServerId, reachedFullHealth)
Medical付属のuseMedicalItem経由では内部で処理済みなので重ねて呼ばない。

独自スライディングを使用する場合（クライアント側の導入元リソースへ追記）：
exports.ptech_mediora_medical:setMedicalSliding(true)  -- 開始時
exports.ptech_mediora_medical:setMedicalSliding(false) -- 終了・キャンセル時
GTA標準のジャンプ・登り・乗り越え・ダイブ／回避動作は自動検知する。
]=]
