
/*_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

リスタートコマンド
/restart jg-advancedgarages

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/*/

Config = {}

-- Localisation
Config.Locale               = "ja"
Config.NumberAndDateFormat  = "en-US"
Config.Currency             = "USD"

-- Framework & Integrations
Config.Framework            = "auto"            -- or "QBCore", "Qbox", "ESX"
Config.FuelSystem           = "lc_fuel"         -- or "LegacyFuel", "ps-fuel", "lj-fuel", "ox_fuel", "cdn-fuel", "hyon_gas_station", "okokGasStation", "nd_fuel", "myFuel", "ti_fuel", "Renewed-Fuel", "rcore_fuel", "lc_fuel", "none"
Config.VehicleKeys          = "qbx_vehiclekeys" -- or "qb-vehiclekeys", "MrNewbVehicleKeys", "jaksam-vehicles-keys", "jc_vehiclekeys", "qs-vehiclekeys", "mk_vehiclekeys", "wasabi_carlock", "cd_garage", "okokGarage", "t1ger_keys", "Renewed", "tgiann-hotwire" "none"
Config.Notifications        = "auto"            -- or "default", "RxNotify", "okokNotify", "ox_lib", "ps-ui"
Config.Banking              = "okokBanking"     -- or "RxBanking", "qb-banking", "qb-management", "esx_addonaccount", "Renewed-Banking", "okokBanking", "fd_banking", "tgg-banking"
Config.Gangs                = "auto"            -- "qb-gangs", "rcore_gangs"

-- Draw text UI prompts (key binding control IDs here: https://docs.fivem.net/docs/game-references/controls/)
Config.DrawText             = "auto" -- or "jg-textui", "qb-DrawText", "okokTextUI", "ox_lib", "ps-ui"

-- キーコンフィグ
Config.OpenGarageKeyBind    = 38                  -- ガレージを開くキー
Config.OpenGaragePrompt     = "[E] Open Garage"   -- 画面通知
Config.OpenImpoundKeyBind   = 38                  -- インパウンドを開くキー
Config.OpenImpoundPrompt    = "[E] Open Impound"  -- 画面通知
Config.InsertVehicleKeyBind = 38                  -- 車両をしまうキー
Config.InsertVehiclePrompt  = "[E] Store Vehicle" -- 画面通知
Config.ExitInteriorKeyBind  = 38                  -- ガレージから出るキー
Config.ExitInteriorPrompt   = "[E] Exit Garage"   -- 画面通知

-- Target
Config.UseTarget            = false
Config.Target               = "ox_target" -- or "qb-target"
Config.TargetPed            = "s_m_y_valet_01"

-- Radial
Config.UseRadialMenu        = false
Config.RadialMenu           = "ox_lib"

-- Little vehicle preview images in the garage UI - learn more/add custom images: https://docs.jgscripts.com/advanced-garages/vehicle-images
Config.ShowVehicleImages       = true
Config.UseJGVehicleStudio      = true
Config.JGVehicleStudioImageSet = "default"

-- Vehicle Spawning & Storing
Config.DoNotSpawnInsideVehicle  = false
Config.SaveVehicleDamage        = true -- Save and apply body and engine damage when taking the vehicle out a garage
Config.AdvancedVehicleDamage    = true -- use Kiminaze's VehicleDeformation
Config.SaveVehiclePropsOnInsert = true
Config.CheckVehicleModel        = true -- Extra security

-- If you don't know what this means, don't touch this
-- If you know what this means, I do recommend enabling it but be aware you may experience reliability issues on more populated servers
-- Having significant issues? I beg you to just set it back to false before opening a ticket with us
-- HIGHLY recommended that you set Config.DoNotSpawnInsideVehicle = false if you decide to enable this
-- Want to read my rant about server spawned vehicles? https://docs.jgscripts.com/advanced-garages/misc/why-are-you-not-using-createvehicleserversetter-by-default
Config.SpawnVehiclesWithServerSetter = false

-- Vehicle Transfers
Config.GarageVehicleTransferCost = 250000 -- Cost to transfer between garages
Config.TransferHidePlayerNames   = false
Config.EnableTransfers = {
  betweenGarages = true,
  betweenPlayers = true
}
Config.DisableTransfersToUnregisteredGarages = false -- Potential hacking protection for vigilant servers - unregistered garages are ones created via events in third-party script integrations, such as housing scripts, and therefore could be prone to script kiddie attacks.

-- Prevent vehicle duplication
-- Learn more: https://docs.jgscripts.com/advanced-garages/vehicle-duplication-prevention
Config.AllowInfiniteVehicleSpawns            = true -- Public & private garages
Config.JobGaragesAllowInfiniteVehicleSpawns  = false -- Job garages（[NOVA] 出ている機体は他の人が出せないように false）
Config.GangGaragesAllowInfiniteVehicleSpawns = true -- Gang garages
Config.GarageVehicleReturnCost               = 250000 -- "towing" tax if not placed back in garage after server restart; or if destroyed or underwater while left out
Config.GarageVehicleReturnCostSocietyFund    = false -- Job name of society fund to pay return fees into (optional)

/*_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  ガレージの設定

  ※ 注意1：ガレージの名前は重複しないこと
  ※ 注意2：レギオンスクエアのガレージの名前を変更した場合、SQLテーブル players_vehicles の garage_id のデフォルト値も同じ名前に変更する必要がある
  ※ 注意3：ガレージはレギオンを参考に、複数の spawn 座標を指定することができます。spawn は車両が出てくる座標

  coords      = ガレージの座標
  spawn       = 車両が出てくる座標（vector4）または複数の座標（vector4 のテーブル）
  distance    = ガレージにアクセスできる有効距離
  type        = 車両の種類 [ car / air / sea ]
  hideBlip    = マップにガレージのアイコンを表示するかどうか
  blip        = マップに表示するガレージのアイコンの設定（id, color, scale）
  hideMarkers = ガレージのマーカーを表示するかどうか
  markers     = ガレージのマーカーの設定（id, size, color, bobUpAndDown, faceCamera, rotate, drawOnEnts）

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/*/

-- Public Garages
Config.GarageShowBlips       = true  -- マップにガレージのアイコンを表示するかどうか
Config.GarageUniqueBlips     = false -- ガレージのアイコンを固有のものにするかどうか
Config.GarageUniqueLocations = true  -- ガレージの座標を固有のものにするかどうか
Config.GarageEnableInteriors = true  -- ガレージのインテリアを有効にするかどうか

-- 共有ガレージの座標と設定
Config.GarageLocations = {

  -- レギオン
  ["Legion Square"] = { -- If you change the name of this garage from Legion Square, you must change the default value of garage_id to the same name in the SQL table players_vehicles
    coords      = vector3(219.23, -794.34, 30.76),
    spawn       = {vector4(216.84, -802.02, 30.78, 69.82), vector4(218.09, -799.42, 30.76, 66.17), vector4(219.29, -797.23, 30.75, 65.4), vector4(219.59, -794.44, 30.75, 69.35), vector4(220.63, -792.03, 30.75, 63.76), vector4(206.81, -798.35, 30.99, 248.53)}, --  you can add multiple spawn locations into a table
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["レギオン ヘリガレージ"] = {
    coords      = vector3(246.54, -750.86, 33.63),
    spawn       = vector4(246.54, -750.86, 33.63, 252.59),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },

  -- メカニック前
  ["メカニック前 ヘリガレージ"] = {
    coords      = vector3(-635.12, 285.47, 80.47),
    spawn       = vector4(-635.12, 285.47, 80.47, 77.58),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },

  -- 狩猟用品店
  ["狩猟用品店 車ガレージ"] = {
    coords      = vector3(-682.45, 5825.44, 16.33),
    spawn       = vector4(-682.45, 5825.44, 16.33, 114.37),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["南署インパウンド 車ガレージ"] = {
    coords      = vector3(418.67, -1638.93, 28.29),
    spawn       = vector4(417.98, -1638.76, 28.29, 89.42),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["採石場 ヘリガレージ"] = {
    coords      = vector3(2941.96, 2785.82, 38.86),
    spawn       = vector4(2941.96, 2785.82, 38.86, 213.98),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["採石場 車ガレージ"] = {
    coords      = vector3(2957.19, 2737.05, 43.04),
    spawn       = vector4(2957.19, 2737.05, 43.04, 305.77),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["鉱山 車ガレージ"] = {
    coords      = vector3(-604.7, 2105.58, 126.74),
    spawn       = vector4(-604.7, 2105.58, 126.74, 41.33),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["ブドウ農園 車ガレージ"] = {
    coords      = vector3(-1918.81, 2048.24, 139.74),
    spawn       = vector4(-1918.81, 2048.24, 139.74, 257.84),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["本署 車ガレージ"] = {
    coords      = vector3(407.48, -997.55, 28.26),
    spawn       = vector4(407.84, -997.81, 28.27, 50.52),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["墓地 ヘリガレージ"] = {
    coords      = vector3(-1657.89, -221.28, 54.0),
    spawn       = vector4(-1657.89, -221.28, 54.0, 161.9),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["墓地 車ガレージ"] = {
    coords      = vector3(-1671.34, -244.74, 53.67),
    spawn       = vector4(-1671.34, -244.74, 53.67, 250.08),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["船着き場 車ガレージ"] = {
    coords      = vector3(-684.08, -1420.12, 4.0),
    spawn       = vector4(-684.08, -1420.12, 4.0, 92.14),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["カヨぺリコ 車ガレージ"] = {
    coords      = vector3(4480.15, -4457.44, 3.24),
    spawn       = vector4(4480.15, -4457.44, 3.24, 199.94),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["カヨぺリコ ヘリガレージ"] = {
    coords      = vector3(4483.59, -4491.91, 3.19),
    spawn       = vector4(4483.59, -4491.91, 3.19, 105.03),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["船着き場 ヘリガレージ"] = {
    coords      = vector3(-724.65, -1444.05, 4.0),
    spawn       = vector4(-724.65, -1444.05, 4.0, 314.69),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["鋳造所 車ガレージ"] = {
    coords      = vector3(1073.68, -1949.67, 30.01),
    spawn       = vector4(1073.68, -1949.67, 30.01, 145.57),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["PDM"] = {
    coords      = vector3(-58.49, -1107.92, 26.44),
    spawn       = vector4(-66.97, -1106.5, 26.01, 78.58),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["casino"] = {
    coords      = vector3(879.35, -9.21, 78.76),
    spawn       = vector4(883.63, -6.45, 78.76, 291.97),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["cafe"] = {
    coords      = vector3(-281.56, -57.86, 49.42),
    spawn       = vector4(-281.74, -57.87, 49.42, 77.62),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["buffshop"] = {
    coords      = vector3(127.02, -1474.64, 29.14),
    spawn       = vector4(127.01, -1474.57, 29.14, 141.12),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["wvAUTO"] = {
    coords      = vector3(-667.15, 295.46, 81.67),
    spawn       = vector4(-667.15, 295.46, 81.67, 78.2),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Islington South"] = {
    coords      = vector3(273.0, -343.85, 44.91),
    spawn       = vector4(270.75, -340.51, 44.92, 342.03),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Grove Street"] = {
    coords      = vector3(14.66, -1728.52, 29.3),
    spawn       = vector4(23.93, -1722.9, 29.3, 310.58),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Mirror Park"] = {
    coords      = vector3(1032.84, -765.1, 58.18),
    spawn       = vector4(1023.2, -764.27, 57.96, 319.66),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Beach"] = {
    coords      = vector3(-1248.69, -1425.71, 4.32),
    spawn       = vector4(-1244.27, -1422.08, 4.32, 37.12),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Great Ocean Highway"] = {
    coords      = vector3(-2961.58, 375.93, 15.02),
    spawn       = vector4(-2964.96, 372.07, 14.78, 86.07),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  -- ["Sandy South"] = {
  --   coords      = vector3(217.33, 2605.65, 46.04),
  --   spawn       = vector4(216.94, 2608.44, 46.33, 14.07),
  --   distance    = 7,
  --   type        = "car",
  --   hideBlip    = false,
  --   blip        = { id = 357, color = 0, scale = 0.7 },
  --   hideMarkers = false,
  --   markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  -- },
  -- ["Sandy North"] = {
  --   coords      = vector3(1878.44, 3760.1, 32.94),
  --   spawn       = vector4(1880.14, 3757.73, 32.93, 215.54),
  --   distance    = 7,
  --   type        = "car",
  --   hideBlip    = false,
  --   blip        = { id = 357, color = 0, scale = 0.7 },
  --   hideMarkers = false,
  --   markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  -- },
  ["North Vinewood Blvd"] = {
    coords      = vector3(365.21, 295.65, 103.46),
    spawn       = vector4(364.84, 289.73, 103.42, 164.23),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  -- ["Grapeseed"] = {
  --   coords      = vector3(1713.06, 4745.32, 41.96),
  --   spawn       = vector4(1710.64, 4746.94, 41.95, 90.11),
  --   distance    = 7,
  --   type        = "car",
  --   hideBlip    = false,
  --   blip        = { id = 357, color = 0, scale = 0.7 },
  --   hideMarkers = false,
  --   markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  -- },
  ["Paleto Bay"] = {
    coords      = vector3(107.32, 6611.77, 31.98),
    spawn       = vector4(110.84, 6607.82, 31.86, 265.28),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Boats"] = {
    coords      = vector3(-795.15, -1510.79, 1.6),
    spawn       = vector4(-798.66, -1507.73, -0.47, 102.23),
    distance    = 10,
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["Hangar"] = {
    coords      = vector3(-1243.49, -3391.88, 13.94),
    spawn       = vector4(-1258.4, -3394.56, 13.94, 328.23),
    distance    = 10,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 359, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },

  ["Arena"] = {
    coords      = vector3(-228.55, -2049.2, 26.92),
    spawn       = vector4(-228.55, -2049.2, 26.92, 315.13),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 36, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["GunSmith"] = {
    coords      = vector3(28.88, -1111.24, 28.91),
    spawn       = vector4(28.88, -1111.24, 28.91, 210.33),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 36, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["ALTERA"] = {
    coords      = vector3(98.09, -4.34, 67.75),
    spawn       = vector4(98.09, -4.34, 67.75, 162.06),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },



  ["ピルボックス病院"] = {
    coords      = vector3(292.81, -609.73, 42.73),
    spawn       = vector4(292.81, -609.73, 42.23, 68.93),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },
  ["ピルボックス病院 航空機"] = {
    coords      = vector3(333.84, -571.23, 70.61),
    spawn       = vector4(333.84, -571.23, 70.61, 338.0),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },
  ["グレイプシード病院"] = {
    coords      = vector3(1670.76, 4752.54, 41.57),
    spawn       = vector4(1670.76, 4752.54, 41.57, 288.44),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },
  ["サンディ病院"] = {
    coords      = vector3(1779.18, 3605.48, 34.34),
    spawn       = vector4(1779.18, 3605.48, 34.34, 26.93),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },
  ["サンディ病院 航空機"] = {
    coords      = vector3(1754.7, 3618.21, 34.31),
    spawn       = vector4(1754.7, 3618.21, 34.31, 214.42),
    distance    = 10,
    type        = "air",
    hideBlip    = true,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },
  ["パレト病院"] = {
    coords      = vector3(-241.47, 6336.4, 31.97),
    spawn       = vector4(-241.47, 6336.4, 31.97, 222.32),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },
  ["パレト病院 航空機"] = {
    coords      = vector3(-261.61, 6344.36, 32.03),
    spawn       = vector4(-261.61, 6344.36, 32.03, 134.25),
    distance    = 10,
    type        = "air",
    hideBlip    = true,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },

  ["Cill-O'Clock"] = {
    coords      = vector3(1192.14, -505.52, 64.06),
    spawn       = vector4(1192.21, -505.57, 64.06, 21.17),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
  },





  -- 番地
  ["5017 車ガレージ"] = {
    coords      = vector3(-1534.64, 1380.91, 123.99),
    spawn       = vector4(-1534.64, 1380.91, 123.99, 354.88),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["2057 車ガレージ"] = {
    coords      = vector3(3310.41, 5147.8, 17.26),
    spawn       = vector4(3310.41, 5147.8, 17.26, 81.08),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["2029 ヘリガレージ"] = {
    coords      = vector3(2131.76, 4809.09, 40.2),
    spawn       = vector4(2131.76, 4809.09, 40.2, 114.61),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["2030 車ガレージ"] = {
    coords      = vector3(2134.51, 4783.91, 39.97),
    spawn       = vector4(2134.51, 4783.91, 39.97, 32.03),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["1012 ヘリガレージ"] = {
    coords      = vector3(129.25, 6613.57, 30.84),
    spawn       = vector4(129.25, 6613.57, 30.84, 222.93),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["3018 車ガレージ"] = {
    coords      = vector3(1666.75, 3766.49, 33.62),
    spawn       = vector4(1666.75, 3766.49, 33.62, 34.06),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["3037 ヘリガレージ"] = {
    coords      = vector3(1770.05, 3239.19, 41.14),
    spawn       = vector4(1770.05, 3239.19, 41.14, 288.32),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["3037 車ガレージ"] = {
    coords      = vector3(1767.87, 3307.09, 40.16),
    spawn       = vector4(1767.87, 3307.09, 40.16, 244.62),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["9110 ヘリガレージ"] = {
    coords      = vector3(5.95, -1749.6, 28.3),
    spawn       = vector4(5.95, -1749.6, 28.3, 319.46),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["7323 ヘリガレージ"] = {
    coords      = vector3(1060.09, -746.9, 56.93),
    spawn       = vector4(1060.09, -746.9, 56.93, 262.87),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["7039 車ガレージ"] = {
    coords      = vector3(-1667.38, 66.58, 62.43),
    spawn       = vector4(-1667.38, 66.58, 62.43, 299.84),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["空港 車ガレージ"] = {
    coords      = vector3(-993.95, -2706.5, 14.02),
    spawn       = vector4(-982.87, -2709.55, 13.83, 342.5),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["7039 ヘリガレージ"] = {
    coords      = vector3(-1695.07, 49.13, 63.76),
    spawn       = vector4(-1695.07, 49.13, 63.76, 45.83),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["8001 車ガレージ"] = {
    coords      = vector3(-1718.53, -1118.42, 12.15),
    spawn       = vector4(-1718.53, -1118.42, 12.15, 47.28),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["10106 車ガレージ"] = {
    coords      = vector3(1142.89, -3288.59, 4.9),
    spawn       = vector4(1142.89, -3288.59, 4.9, 267.04),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["10014 車ガレージ"] = {
    coords      = vector3(-1283.61, -3402.61, 12.94),
    spawn       = vector4(-1283.61, -3402.61, 12.94, 329.06),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["10109 ヘリガレージ"] = {
    coords      = vector3(1142.81, -3261.49, 4.9),
    spawn       = vector4(1142.81, -3261.49, 4.9, 270.27),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["9372 車ガレージ"] = {
    coords      = vector3(1440.37, -2610.73, 47.26),
    spawn       = vector4(1440.37, -2610.73, 47.26, 343.78),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["9395 船ガレージ"] = {
    coords      = vector3(2840.51, -723.58, 1.16),
    spawn       = vector4(2850.15, -724.32, -1.2, 257.01),
    distance    = 7,
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["9395 車ガレージ"] = {
    coords      = vector3(2787.22, -710.22, 4.94),
    spawn       = vector4(2778.92, -712.0, 4.52, 102.08),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["2057 船ガレージ"] = {
    coords      = vector3(3369.99, 5184.04, 1.46),
    spawn       = vector4(3371.53, 5187.25, -1.4, 258.31),
    distance    = 7,
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["10107 船ガレージ※出したら戻せないので注意"] = {
    coords      = vector3(1160.94, -3348.03, 5.9),
    spawn       = vector4(1159.33, -3358.61, -0.86, 173.68),
    distance    = 7,
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["ハンティング近く 船ガレージ"] = {
    coords      = vector3(-885.91, 5829.21, 1.4),
    spawn       = vector4(-902.23, 5830.98, -1.04, 72.7),
    distance    = 7,
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["リサセン 車ガレージ"] = {
    coords      = vector3(50.03, 6464.46, 31.43),
    spawn       = vector4(55.05, 6459.94, 31.36, 225.07),
    distance    = 7,
    type        = "car",
    hideBlip    = false,
    blip        = { id = 356, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["リサセン ヘリガレージ"] = {
    coords      = vector3(35.32, 6449.92, 31.43),
    spawn       = vector4(43.66, 6448.36, 31.38, 135.79),
    distance    = 7,
    type        = "air",
    hideBlip    = false,
    blip        = { id = 43, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers     = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
}

-- Private Garages
Config.PrivGarageCreateCommand        = "privategarages"
Config.PrivGarageCreateJobRestriction = {"realestate"}
Config.PrivGarageEnableInteriors      = true
Config.PrivGarageHideBlips            = false
Config.PrivGarageBlip                 = { id = 357, color = 0, scale = 0.7 }

-- Job Garages
Config.JobGarageShowBlips            = true               -- ジョブガレージの地図上のアイコンを表示するかどうか
Config.JobGarageSetVehicleCommand    = "setjobvehicle"    -- 管理者専用：乗っている車両をジョブガレージに登録する
Config.JobGarageRemoveVehicleCommand = "removejobvehicle" -- 管理者専用：乗っている車両をジョブガレージから削除する
Config.JobGarageUniqueBlips          = false              -- ジョブガレージの地図上のアイコンをユニークにするかどうか（同じ座標に複数のジョブガレージがある場合、アイコンは1つだけ表示される）
Config.JobGarageUniqueLocations      = true               -- ジョブガレージの座標をユニークにするかどうか（同じ座標に複数のジョブガレージを作ることはできない）
Config.JobGarageEnableInteriors      = true               -- ジョブガレージのインテリアを有効化するかどうか

-- ジョブガレージの座標と設定
Config.JobGarageLocations = {
  ["Mechanic"] = {
    coords      = vector3(157.86, -3005.9, 7.03),
    spawn       = vector4(165.26, -3014.94, 5.9, 268.8),
    distance    = 7,
    job         = {"mechanic"},
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = true,
    markers = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- Use owned vehicles that can anyone in this society can access - more details: https://docs.jgscripts.com/advanced-garages/job-and-gang-garages
  },
  ["Police Car本署"] = {
    coords      = vec3(442.41, -1025.9, 28.71),
    spawn       = vec4(437.99, -1020.79, 27.7, 89.83),
    distance    = 7,
    job         = {"police"},
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 38, scale = 0.7 },
    hideMarkers = false,
    markers = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有車（耐久・燃料が保存され、出ている車は他の人が出せない）
    -- 車両本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Car2本署"] = {
    coords      = vec3(441.45, -992.67, 25.7),
    spawn       = vec4(431.34, -979.45, 24.7, 181.1),
    distance    = 7,
    job         = {"police"},
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 38, scale = 0.7 },
    hideMarkers = false,
    markers = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有車（耐久・燃料が保存され、出ている車は他の人が出せない）
    -- 車両本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Car南署"] = {
    coords      = vec3(388.95, -1612.81, 29.29),
    spawn       = vec4(384.01, -1615.71, 28.29, 235.76),
    distance    = 7,
    job         = {"police"},
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 38, scale = 0.7 },
    hideMarkers = false,
    markers = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有車（耐久・燃料が保存され、出ている車は他の人が出せない）
    -- 車両本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Car2南署"] = {
    coords      = vec3(353.59, -1626.51, 23.79),
    spawn       = vec4(343.32, -1630.71, 22.79, 224.18),
    distance    = 7,
    job         = {"police"},
    type        = "car",
    hideBlip    = false,
    blip        = { id = 357, color = 38, scale = 0.7 },
    hideMarkers = false,
    markers = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有車（耐久・燃料が保存され、出ている車は他の人が出せない）
    -- 車両本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Heliport2本署"] = { -- MRPD屋上ヘリポート（police専用）
    coords       = vector3(481.62, -982.29, 41.01),
    spawn        = vector4(481.57, -982.22, 40.01, 92.33),
    distance    = 10,
    job          = {"police"},
    type         = "air",
    hideBlip     = false,
    blip         = { id = 43, color = 38, scale = 0.7 },
    hideMarkers  = false,
    markers      = { id = 34, size = { x = 1.0, y = 1.0, z = 1.0 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有ヘリ（耐久・燃料が保存され、出ている機体は他の人が出せない）
    -- ヘリ本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Heliport本署"] = { -- MRPD屋上ヘリポート（police専用）
    coords       = vector3(449.16, -981.3, 43.69),
    spawn        = vector4(449.16, -981.3, 43.69, 88.43),
    distance    = 10,
    job          = {"police"},
    type         = "air",
    hideBlip     = false,
    blip         = { id = 43, color = 38, scale = 0.7 },
    hideMarkers  = false,
    markers      = { id = 34, size = { x = 1.0, y = 1.0, z = 1.0 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有ヘリ（耐久・燃料が保存され、出ている機体は他の人が出せない）
    -- ヘリ本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Heliport南署"] = { -- MRPD屋上ヘリポート（police専用）
    coords       = vector3(362.72, -1598.56, 36.95),
    spawn        = vector4(362.72, -1598.56, 36.95, 319.13),
    distance    = 10,
    job          = {"police"},
    type         = "air",
    hideBlip     = false,
    blip         = { id = 43, color = 38, scale = 0.7 },
    hideMarkers  = false,
    markers      = { id = 34, size = { x = 1.0, y = 1.0, z = 1.0 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有ヘリ（耐久・燃料が保存され、出ている機体は他の人が出せない）
    -- ヘリ本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },

  ["Police Airport"] = { -- MRPD屋上ヘリポート（police専用）
    coords       = vector3(-1287.0, -3371.16, 13.94),
    spawn        = vector4(-1287.17, -3371.33, 12.94, 330.95),
    distance    = 10,
    job          = {"police"},
    type         = "air",
    hideBlip     = false,
    blip         = { id = 359, color = 38, scale = 0.7 },
    hideMarkers  = false,
    markers      = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有ヘリ（耐久・燃料が保存され、出ている機体は他の人が出せない）
    -- ヘリ本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Airport2"] = { -- MRPD屋上ヘリポート（police専用）
    coords       = vector3(1740.85, 3260.39, 41.31),
    spawn        = vector4(1724.94, 3256.2, 40.18, 105.18),
    distance    = 10,
    job          = {"police"},
    type         = "air",
    hideBlip     = false,
    blip         = { id = 359, color = 38, scale = 0.7 },
    hideMarkers  = false,
    markers      = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有ヘリ（耐久・燃料が保存され、出ている機体は他の人が出せない）
    -- ヘリ本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },

  ["Police Boat"] = {
    coords      = vec3(-860.29, -1323.49, 1.61),
    spawn       = vec4(-859.18, -1328.23, -0.4, 113.54),
    distance    = 7,
    job         = {"police"},
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 38, scale = 0.7 },
    hideMarkers = false,
    markers = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有車（耐久・燃料が保存され、出ている車は他の人が出せない）
    -- 車両本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },
  ["Police Boat2"] = {
    coords      = vec3(1197.35, -2703.47, 1.15),
    spawn       = vec4(1197.18, -2716.23, -1.18, 178.56),
    distance    = 7,
    job         = {"police"},
    type        = "sea",
    hideBlip    = false,
    blip        = { id = 356, color = 38, scale = 0.7 },
    hideMarkers = false,
    markers = { id = 21, size = { x = 0.5, y = 0.5, z = 0.5 }, color = { r = 0, g = 120, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "owned", -- [NOVA] DBに登録された警察所有車（耐久・燃料が保存され、出ている車は他の人が出せない）
    -- 車両本体は Config.NvJobVehiclesAutoRegister でサーバー起動時に自動登録される
  },




  ["ピルボックス病院 EMS"] = {
    coords      = vector3(291.15, -587.04, 42.7),
    spawn       = vector4(291.15, -587.04, 42.7, 341.16),
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 357, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "car",
    vehiclesType = "owned",
  },
  ["ピルボックス病院 EMS航空機"] = {
    coords      = vector3(294.9, -567.79, 42.36),
    spawn       = vector4(320.37, -593.09, 95.19, 65.87),
    storeCoords = vector3(320.37, -593.09, 93.89),

    instantReturnGroup = "ems_air",
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 360, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 23,
      size         = { x = 5.0, y = 5.0, z = 5.0 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "air",
    vehiclesType = "owned",
  },
  ["ピルボックス病院 航空機"] = {
    coords      = vector3(333.84, -571.23, 70.61),
    spawn       = vector4(333.84, -571.23, 70.01, 338.0),
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 360, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "air",
    vehiclesType = "owned",
  },

  ["グレイプシード病院 EMS"] = {
    coords      = vector3(1670.76, 4752.54, 41.57),
    spawn       = vector4(1670.76, 4752.54, 41.57, 288.44),
    distance    = 7,
    hideBlip    = true,
    blip        = { id = 357, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "car",
    vehiclesType = "owned",
  },

  ["サンディ病院 EMS"] = {
    coords      = vector3(1779.18, 3605.48, 34.34),
    spawn       = vector4(1779.18, 3605.48, 34.34, 26.93),
    distance    = 7,
    hideBlip    = true,
    blip        = { id = 357, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "car",
    vehiclesType = "owned",
  },
  ["サンディ病院 航空機"] = {
    coords      = vector3(1754.7, 3618.21, 34.31),
    spawn       = vector4(1754.7, 3618.21, 34.31, 214.42),
    instantReturnGroup = "ems_air",
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 360, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = { "ambulance" },
    type = "air",
    vehiclesType = "owned",
  },
  ["サンディ病院 EMS航空機"] = {
    coords      = vector3(1770.36, 3592.67, 34.44),
    spawn       = vector4(1770.36, 3592.67, 35.44, 24.01),
    instantReturnGroup = "ems_air",
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 360, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 23,
      size         = { x = 10.0, y = 10.0, z = 10.0 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = { "ambulance" },
    type = "air",
    vehiclesType = "owned",
  },

  ["パレト病院"] = {
    coords      = vector3(-241.47, 6336.4, 31.97),
    spawn       = vector4(-241.47, 6336.4, 31.97, 222.32),
    distance    = 7,
    hideBlip    = true,
    blip        = { id = 357, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "car",
    vehiclesType = "owned",
  },
  ["パレト病院 航空機"] = {
    coords      = vector3(-261.61, 6344.36, 32.03),
    spawn       = vector4(-261.61, 6344.36, 32.03, 134.25),
    instantReturnGroup = "ems_air",
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 360, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "air",
    vehiclesType = "owned",
  },
  ["パレト病院 EMS航空機"] = {
    coords      = vector3(-252.97, 6335.16, 31.43),
    spawn       = vector4(-245.48, 6326.32, 38.02, 219.83),
    storeCoords = vector3(-245.48, 6326.32, 36.92),
    instantReturnGroup = "ems_air",
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 360, color = 2, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 23,
      size         = { x = 5.0, y = 5.0, z = 5.0 },
      color        = { r = 80, g = 200, b = 120, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = {"ambulance"},
    type = "air",
    vehiclesType = "spawner",
  },

  ["個人医"] = {
    coords      = vector3(957.72, -204.36, 72.73),
    spawn       = vector4(957.72, -204.36, 72.73, 322.63),
    distance    = 7,
    hideBlip    = true,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 36,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = { "private_medic" },
    type = "car",
    vehiclesType = "personal",
  },
  ["個人医 航空機"] = {
    coords      = vector3(981.93, -221.52, 69.09),
    spawn       = vector4(981.93, -221.52, 69.09, 323.73),
    distance    = 10,
    hideBlip    = true,
    blip        = { id = 357, color = 0, scale = 0.7 },
    hideMarkers = false,
    markers = {
      id           = 34,
      size         = { x = 0.5, y = 0.5, z = 0.5 },
      color        = { r = 255, g = 255, b = 255, a = 120 },
      bobUpAndDown = 0,
      faceCamera   = 0,
      rotate       = 1,
      drawOnEnts   = 0
    },
    job = { "private_medic" },
    type = "air",
    vehiclesType = "personal",
  },
}

/*_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  [NOVA] ジョブ所有車両の自動登録（サーバー起動時、未登録のナンバーだけ追加する）
  ここで登録した機体は jg の「owned」ジョブガレージに並び、耐久・燃料がしまった時の状態のまま保存される
  count を減らすと、超えた番号の車両（このナンバーの頭文字のジョブ所有車）は起動時に DB から削除される

  job            = 所有ジョブ
  garage         = しまわれるガレージ（Config.JobGarageLocations の名前）
  model          = 車両モデル名
  count          = 台数
  platePrefix    = ナンバー：PDHELI01〜PDHELI10（8文字以内）
  nicknamePrefix = 表示名前半
  nicknameSuffix = 表示名後半
  minJobGrade    = 使えるグレード
  livery         = リバリー番号 / extras = オンにするエクストラ（書いたもの以外はオフ。省略するとエクストラは触らない）
_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/*/

-- Qbox の player_vehicles には「citizenid は実在キャラのみ」という外部キー制約があり、
-- ジョブ所有車（citizenid にジョブ名が入る）を登録できないため、起動時にこの制約を外す
Config.NvDropVehicleOwnerForeignKey = true

-- [NOVA] 警察のグレード番号（qbx_core の jobs.lua の police の grades と合わせる）
local NvPoliceGrade = {
  ["体験"]     = 0,
  ["新人"]     = 1,
  ["巡査"]     = 2,
  ["巡査長"]   = 3,
  ["巡査部長"] = 4,
  ["警視正"]   = 5,
  ["副署長"]   = 6,
  ["署長"]     = 7,
}

-- ジョブ車両の登録
Config.NvJobVehiclesAutoRegister = {
  {
    job            = "police",
    garage         = "Police Heliport本署", -- 以前の "Police Heliport" は存在しないガレージ名だった
    model          = "polmav",
    count          = 10,
    platePrefix    = "PDHELI", -- ナンバー：PDHELI01〜PDHELI10（8文字以内）
    nicknamePrefix = "警察ヘリ ", -- 表示名：警察ヘリ 1号機〜
    nicknameSuffix = "号機",
    minJobGrade    = 0,
    livery         = 0,
  },
  {
    job            = "police",
    garage         = "Police Car本署",
    model          = "police",
    count          = 1,
    platePrefix    = "POLCA", -- POLCA01
    nicknamePrefix = "パトカー ",
    nicknameSuffix = "号車",
    minJobGrade    = 0,
    livery         = 1,
  },
  {
    job            = "police",
    garage         = "Police Car本署",
    model          = "police2",
    count          = 1,
    platePrefix    = "POLCB", -- POLCB01
    nicknamePrefix = "パトカー2 ",
    nicknameSuffix = "号車",
    minJobGrade    = 3,
    livery         = 2,
  },

  -- MODパトカー（各1台、ナンバー NPD0101〜）
  -- 署長（署長以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpoltr3s",        count = 1, platePrefix = "NPD01", nickname = "署長 gbpoltr3s",           minJobGrade = NvPoliceGrade["署長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolterrorizer",  count = 1, platePrefix = "NPD02", nickname = "署長 gbpolterrorizer",     minJobGrade = NvPoliceGrade["署長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolturismogt",   count = 1, platePrefix = "NPD03", nickname = "署長 gbpolturismogt",      minJobGrade = NvPoliceGrade["署長"] },
  -- 副署長（副署長以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpolstarlight",   count = 1, platePrefix = "NPD04", nickname = "副署長 gbpolstarlight",    minJobGrade = NvPoliceGrade["副署長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolcometcl",     count = 1, platePrefix = "NPD05", nickname = "副署長 gbpolcometcl",      minJobGrade = NvPoliceGrade["副署長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolargento7f",   count = 1, platePrefix = "NPD06", nickname = "副署長 gbpolargento7f",    minJobGrade = NvPoliceGrade["副署長"] },
  -- 警視正（警視正以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpolcomets2r",    count = 1, platePrefix = "NPD07", nickname = "警視正 gbpolcomets2r",     minJobGrade = NvPoliceGrade["警視正"] },
  { job = "police", garage = "Police Car本署", model = "gbpoldomgsx",      count = 1, platePrefix = "NPD08", nickname = "警視正 gbpoldomgsx",       minJobGrade = NvPoliceGrade["警視正"] },
  { job = "police", garage = "Police Car本署", model = "gbpolgresley",     count = 1, platePrefix = "NPD09", nickname = "警視正 gbpolgresley",      minJobGrade = NvPoliceGrade["警視正"] },
  { job = "police", garage = "Police Car本署", model = "gbpolimpaler",     count = 1, platePrefix = "NPD10", nickname = "警視正 gbpolimpaler",      minJobGrade = NvPoliceGrade["警視正"] },
  -- 巡査部長（巡査部長以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpoleon",         count = 1, platePrefix = "NPD11", nickname = "巡査部長 gbpoleon",         minJobGrade = NvPoliceGrade["巡査部長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolechelon",     count = 1, platePrefix = "NPD12", nickname = "巡査部長 gbpolechelon",     minJobGrade = NvPoliceGrade["巡査部長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolesperta",     count = 1, platePrefix = "NPD13", nickname = "巡査部長 gbpolesperta",     minJobGrade = NvPoliceGrade["巡査部長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolsentinelgts", count = 1, platePrefix = "NPD14", nickname = "巡査部長 gbpolsentinelgts", minJobGrade = NvPoliceGrade["巡査部長"] },
  -- 巡査長（巡査長以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpolmojave",      count = 1, platePrefix = "NPD15", nickname = "巡査長 gbpolmojave",        minJobGrade = NvPoliceGrade["巡査長"] },
  { job = "police", garage = "Police Car本署", model = "gbpoltahomagt",    count = 1, platePrefix = "NPD16", nickname = "巡査長 gbpoltahomagt",      minJobGrade = NvPoliceGrade["巡査長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolsultanrsx",   count = 1, platePrefix = "NPD17", nickname = "巡査長 gbpolsultanrsx",     minJobGrade = NvPoliceGrade["巡査長"] },
  { job = "police", garage = "Police Car本署", model = "gbpolclubxr",      count = 1, platePrefix = "NPD18", nickname = "巡査長 gbpolclubxr",        minJobGrade = NvPoliceGrade["巡査長"] },
  -- 巡査（巡査以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpolstanier",     count = 1, platePrefix = "NPD19", nickname = "巡査 gbpolstanier",         minJobGrade = NvPoliceGrade["巡査"] },
  { job = "police", garage = "Police Car本署", model = "gbpolbisonstx",    count = 1, platePrefix = "NPD20", nickname = "巡査 gbpolbisonstx",        minJobGrade = NvPoliceGrade["巡査"] },
  { job = "police", garage = "Police Car本署", model = "gbpolbisonhf",     count = 1, platePrefix = "NPD21", nickname = "巡査 gbpolbisonhf",         minJobGrade = NvPoliceGrade["巡査"] },
  { job = "police", garage = "Police Car本署", model = "gbpolscoutgsx",    count = 1, platePrefix = "NPD22", nickname = "巡査 gbpolscoutgsx",        minJobGrade = NvPoliceGrade["巡査"] },
  -- 新人（新人以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpolhedra",       count = 1, platePrefix = "NPD23", nickname = "新人 gbpolhedra",           minJobGrade = NvPoliceGrade["新人"] },
  { job = "police", garage = "Police Car本署", model = "gbpolsolace",      count = 1, platePrefix = "NPD24", nickname = "新人 gbpolsolace",          minJobGrade = NvPoliceGrade["新人"] },
  { job = "police", garage = "Police Car本署", model = "gbpolsteedvan",    count = 1, platePrefix = "NPD25", nickname = "新人 gbpolsteedvan",        minJobGrade = NvPoliceGrade["新人"] },
  -- 体験（体験以上が使える）
  { job = "police", garage = "Police Car本署", model = "gbpoladmiral",     count = 1, platePrefix = "NPD26", nickname = "体験 gbpoladmiral",         minJobGrade = NvPoliceGrade["体験"] },

  -- 救急車
  -- {
  --   job = "ambulance",
  --   garage = "EMS Pillbox",
  --   model = "ambulance",
  --   count = 3,
  --   platePrefix = "EMSAMB",
  --   nicknamePrefix = "救急車 ",
  --   nicknameSuffix = "号車",
  --   minJobGrade = 0,
  --   livery = 0,
  -- },
}

-- [NOVA] 外見の固定：ガレージから出すたびにこの見た目に戻す
-- livery = リバリー番号 / extras = オンにするエクストラ（書いたもの以外はオフ。省略するとエクストラは触らない）
-- polmav は 0 = 警察（LSPD）。もし救急ヘリの見た目になる場合は 1 に変えてみてください
Config.NvForcedLooks = {
  -- ["polmav"]  = { livery = 0 },
  ["police"]  = { livery = 1, extras = {1, 2} },
  ["police2"] = { livery = 2 },
}

-- [NOVA] すぐ出しガレージ：Eを押すとメニューを開かずに即スポーン＆乗車、乗ったままEでその場でしまう
-- キーはジョブガレージ名（Config.JobGarageLocations の名前と同じにする）
-- 例：
-- ["Police Heliport"] = { model = "polmav", vehicleType = "heli", livery = 0, platePrefix = "POL" },
Config.InstantSpawnGarages = {
  -- 現在は使用していない（ヘリポートは通常のガレージ画面でヘリを選ぶ方式）
  ["ピルボックス病院 EMS航空機"] = {
    model = "polmav",
    vehicleType = "heli",
    passengerSeats = 3,
    livery = 1,
    platePrefix = "EMS"
  },
  ["サンディ病院 EMS航空機"] = {
    model = "polmav",
    vehicleType = "heli",
    passengerSeats = 3,
    livery = 1,
    platePrefix = "EMS"
  },
  ["パレト病院 EMS航空機"] = {
    model = "polmav",
    vehicleType = "heli",
    passengerSeats = 3,
    livery = 1,
    platePrefix = "EMS"
  },
}

-- Gang Garages (QBCore/Qbox only by default)
Config.GangEnableCustomESXIntegration = false -- Set to true if you've added a custom system to cl/sv-functions.lua
Config.GangGarageShowBlips            = true
Config.GangGarageSetVehicleCommand    = "setgangvehicle"    -- admin only
Config.GangGarageRemoveVehicleCommand = "removegangvehicle" -- admin only
Config.GangGarageUniqueBlips          = false
Config.GangGarageUniqueLocations      = true
Config.GangGarageEnableInteriors      = true
Config.GangGarageLocations = { -- IMPORTANT - Every garage name must be unique
  ["The Lost MC"] = {
    coords       = vector3(439.18, -1518.48, 29.28),
    spawn        = vector4(439.18, -1518.48, 29.28, 139.06),
    distance     = 15,
    gang         = {"lostmc"},
    type         = "car",
    hideBlip     = false,
    blip         = { id = 357, color = 0, scale = 0.7 },
    hideMarkers  = true,
    markers      = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
    vehiclesType = "personal", -- Use personal vehicles
  }
}

-- Impound
Config.ImpoundCommand         = "jgiv"   -- [NOVA] jg本体の押収コマンド（プレイヤーは /iv を使う。/iv は sv/cl-functions の NOVA 版）
Config.NvImpoundCommand       = "iv"     -- [NOVA] 所有車→jgの押収画面 / NPC・管理者・ジョブスポーンなど未登録車→その場で消去
Config.ImpoundFeesSocietyFund = "police" -- Job name of society fund to pay impound fees into (optional)
Config.ImpoundShowBlips       = true
Config.ImpoundUniqueBlips     = false
Config.ImpoundTimeOptions     = {0, 1, 4, 12, 24, 72, 168} -- in hours
Config.ImpoundLocations = { -- IMPORTANT - Every impound name must be unique
  ["車インパウンド場"] = {
    coords       = vector3(410.8, -1626.26, 29.29),
    spawn        = vector4(408.44, -1630.88, 29.29, 136.88),
    distance     = 15,
    type         = "car",
    job          = {"police"},
    hideBlip     = false,
    blip         = { id = 68, color = 0, scale = 0.7 },
    hideMarkers  = true,
    markers      = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["ヘリインパウンド場"] = {
    coords       = vector3(-745.34, -1468.52, 4.0),
    spawn        = vector4(-745.34, -1468.52, 4.0, 318.2),
    distance     = 15,
    type         = "air",
    job          = {"police"},
    hideBlip     = false,
    blip         = { id = 68, color = 0, scale = 0.7 },
    hideMarkers  = true,
    markers      = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 0, rotate = 1, drawOnEnts = 0 },
  },
  ["ボートインパウンド場"] = {
    coords       = vector3(-800.65, -1494.8, 1.59),
    spawn        = vector4(-802.72, -1489.0, 0.81, 113.1),
    distance     = 15,
    type         = "sea",
    job          = {"police"},
    hideBlip     = false,
    blip         = { id = 68, color = 0, scale = 0.7 },
    hideMarkers  = false,
    markers      = { id = 21, size = { x = 0.3, y = 0.3, z = 0.3 }, color = { r = 255, g = 255, b = 255, a = 120 }, bobUpAndDown = 0, faceCamera = 1, rotate = 1, drawOnEnts = 0 },
  }
}

-- Garage Interior
Config.GarageInteriorEntrance = vector4(227.96, -1003.06, -99.0, 0.0)
Config.GarageInteriorCameraCutscene = {
  vector4(227.96, -977.81, -98.99, 0.0),  -- from
  vector4(227.96, -1006.96, -98.99, 0.0), -- to (this should be the entrance, or slightly further back from the entrance coords for a better final player transition)
}
Config.GarageInteriorVehiclePositions = {
  vector4(233.000000, -984.000000, -99.410004, 118.000000),
  vector4(233.000000, -988.500000, -99.410004, 118.000000),
  vector4(233.000000, -993.000000, -99.410004, 118.000000),
  vector4(233.000000, -997.500000, -99.410004, 118.000000),
  vector4(233.000000, -1002.000000, -99.410004, 118.000000),
  vector4(223.600006, -979.000000, -99.410004, 235.199997),
  vector4(223.600006, -983.599976, -99.410004, 235.199997),
  vector4(223.600006, -988.200012, -99.410004, 235.199997),
  vector4(223.600006, -992.799988, -99.410004, 235.199997),
  vector4(223.600006, -997.400024, -99.410004, 235.199997),
  vector4(223.600006, -1002.000000, -99.410004, 235.199997),
}

-- Staff Commands
Config.ChangeVehiclePlate    = "vplate"  -- admin only
Config.DeleteVehicleFromDB   = "dvdb"    -- admin only
Config.ReturnVehicleToGarage = "vreturn" -- admin only

-- Add your import vehicle's spawn name and desired label here for pretty vehicle names in the garage
-- This is mainly designed for ESX - if you are using QB, do this in shared!
Config.VehicleLabels = {
  ["spawnName"] = "Pretty Vehicle Label"
}

-- Block certain vehicles from being transferred to other players
Config.PlayerTransferBlacklist = {
  "spawnName"
}

Config.AutoRunSQL = true
Config.ReturnToPreviousRoutingBucket = false
Config.HideWatermark = false
Config.__v3Config = true
Config.Debug = false
