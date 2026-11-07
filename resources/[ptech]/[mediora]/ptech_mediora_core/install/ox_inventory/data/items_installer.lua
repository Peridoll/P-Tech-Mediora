return {
	['testburger'] = {
		label = 'テストバーガー',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'なんて最高においしいバーガーなんだ、そう思わない？'
		},
		buttons = {
			{
				label = 'なめる',
				action = function(slot)
					print('バーガーをなめた')
				end
			},
			{
				label = '握りつぶす',
				action = function(slot)
					print('バーガーを握りつぶした :(')
				end
			},
			{
				label = 'ヴィーガンバーガーを何と呼ぶ？',
				group = 'ハンバーガーダジャレ',
				action = function(slot)
					print('ミステーキ（間違い＋ステーキ）。')
				end
			},
			{
				label = 'カエルはハンバーガーと一緒に何を食べる？',
				group = 'ハンバーガーダジャレ',
				action = function(slot)
					print('フレンチフライ（ハエ）。')
				end
			},
			{
				label = 'バーガーとポテトはなぜ走っていた？',
				group = 'ハンバーガーダジャレ',
				action = function(slot)
					print('ファストフードだから。')
				end
			}
		},
		consume = 0.3
	},

	['bandage'] = {
		label = '包帯',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = '汚れた金',
	},

	['burger'] = {
		label = 'バーガー',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'おいしいバーガーを食べた'
		},
	},

	['sprunk'] = {
		label = 'スプランク',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'スプランクで喉を潤した'
		}
	},

	['parachute'] = {
		label = 'パラシュート',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'ゴミ',
	},

	['paperbag'] = {
		label = '紙袋',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = '身分証',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'パンツ',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
		label = 'ロックピック',
		weight = 160,
	},

	['phone'] = {
		label = 'スマートフォン',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = '現金',
	},

	['mustard'] = {
		label = 'マスタード',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'マスタードを…飲んだ'
		}
	},

	['water'] = {
		label = '水',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = '爽やかな水を飲んだ'
		}
	},

	['radio'] = {
    label = '無線機',
    weight = 500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'nova-radio.useRadio'
    }
},

	['armour'] = {
		label = '防弾ベスト',
		weight = 3000,
		stack = true,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = '衣服',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleecaカード',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'スクラップメタル',
		weight = 80,
	},

	["firework1"] = {
		label = "ツーブラザーズ",
		weight = 1000,
		stack = true,
		close = true,
		description = "花火",
		client = {
			image = "firework1.png",
		}
	},

	["electronickit"] = {
		label = "電子キット",
		weight = 100,
		stack = true,
		close = true,
		description = "ロボットを作りたいと思っていたなら、ここから始められるかも。君が次のイーロン・マスクになるかもね？",
		client = {
			image = "electronickit.png",
		}
	},

	["slanted_muzzle_brake"] = {
		label = "スランテッドマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "slanted_muzzle_brake.png",
		}
	},

	["clip_attachment"] = {
		label = "マガジン",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマガジン",
		client = {
			image = "clip_attachment.png",
		}
	},

	["barrel_attachment"] = {
		label = "バレル",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のバレル",
		client = {
			image = "barrel_attachment.png",
		}
	},

	["heavy_duty_muzzle_brake"] = {
		label = "HDマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "heavy_duty_muzzle_brake.png",
		}
	},

	["weaponlicense"] = {
		label = "武器所持許可証",
		weight = 0,
		stack = false,
		close = true,
		description = "武器所持許可証",
		client = {
			image = "weapon_license.png",
		}
	},

	["cokebaggy"] = {
		label = "コカインの袋",
		weight = 0,
		stack = true,
		close = true,
		description = "手っ取り早くハイになれる",
		client = {
			image = "cocaine_baggy.png",
		}
	},

	["leopardcamo_attachment"] = {
		label = "レオパード迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のレオパード迷彩",
		client = {
			image = "leopardcamo_attachment.png",
		}
	},

	["weed_brick"] = {
		label = "大麻ブロック",
		weight = 1000,
		stack = true,
		close = true,
		description = "大口の客に売るための1kgの大麻ブロック",
		client = {
			image = "weed_brick.png",
		}
	},

	["largescope_attachment"] = {
		label = "ラージスコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のラージスコープ",
		client = {
			image = "largescope_attachment.png",
		}
	},

	["coffee"] = {
		label = "コーヒー",
		weight = 200,
		stack = true,
		close = true,
		description = "カフェインを注入しよう",
		client = {
			image = "coffee.png",
		}
	},

	["tunerlaptop"] = {
		label = "チューナーチップ",
		weight = 2000,
		stack = false,
		close = true,
		description = "このチューナーチップで車をドーピングできる…使い方がわかっていればね",
		client = {
			image = "tunerchip.png",
		}
	},

	["bank_card"] = {
		label = "銀行カード",
		weight = 0,
		stack = false,
		close = true,
		description = "ATMを利用するためのカード",
		client = {
			image = "bank_card.png",
		}
	},

	["ifaks"] = {
		label = "IFAK（個人用救急キット）",
		weight = 200,
		stack = true,
		close = true,
		description = "回復とストレスを完全に取り除くためのIFAK",
		client = {
			image = "ifaks.png",
			export = "novill-ifak.useIfak",
		}
	},

	["firework4"] = {
		label = "ウィーピングウィロー",
		weight = 1000,
		stack = true,
		close = true,
		description = "花火",
		client = {
			image = "firework4.png",
		}
	},

	["meth"] = {
		label = "メス",
		weight = 100,
		stack = true,
		close = true,
		description = "メスの小袋",
		client = {
			image = "meth_baggy.png",
		}
	},

	["weed_amnesia_seed"] = {
		label = "アムネジアの種",
		weight = 0,
		stack = true,
		close = true,
		description = "アムネジアの大麻の種",
		client = {
			image = "weed_seed.png",
		}
	},

	["driver_license"] = {
		label = "運転免許証",
		weight = 0,
		stack = false,
		close = false,
		description = "車両を運転できることを証明する許可証",
		client = {
			image = "driver_license.png",
		}
	},

	["wine"] = {
		label = "ワイン",
		weight = 300,
		stack = true,
		close = false,
		description = "素敵な夜に飲む上等なワイン",
		client = {
			image = "wine.png",
		}
	},

	["drum_attachment"] = {
		label = "ドラムマガジン",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のドラムマガジン",
		client = {
			image = "drum_attachment.png",
		}
	},

	["diving_gear"] = {
		label = "ダイビングギア",
		weight = 30000,
		stack = false,
		close = true,
		description = "酸素タンクとリブリーザー",
		client = {
			image = "diving_gear.png",
		}
	},

	["gatecrack"] = {
		label = "ゲートクラック",
		weight = 0,
		stack = true,
		close = true,
		description = "フェンスを破るための便利なソフトウェア",
		client = {
			image = "usb_device.png",
		}
	},

	["security_card_02"] = {
		label = "セキュリティカードB",
		weight = 0,
		stack = true,
		close = true,
		description = "セキュリティカード…どこで使うんだろう",
		client = {
			image = "security_card_02.png",
		}
	},

	["coke_small_brick"] = {
		label = "コカインパッケージ",
		weight = 350,
		stack = false,
		close = true,
		description = "コカインの小さな包み。主に取引に使われ、場所を取る",
		client = {
			image = "coke_small_brick.png",
		}
	},

	["moneybag"] = {
		label = "現金袋",
		weight = 0,
		stack = false,
		close = true,
		description = "現金の入った袋",
		client = {
			image = "moneybag.png",
		}
	},

	["empty_weed_bag"] = {
		label = "空の大麻袋",
		weight = 0,
		stack = true,
		close = true,
		description = "小さな空の袋",
		client = {
			image = "weed_baggy_empty.png",
		}
	},

	["veh_xenons"] = {
		label = "キセノン",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のキセノンをアップグレード",
		client = {
			image = "veh_xenons.png",
		}
	},

	["labkey"] = {
		label = "カギ",
		weight = 500,
		stack = false,
		close = true,
		description = "何かの錠前のカギ…？",
		client = {
			image = "labkey.png",
		}
	},

	["brushcamo_attachment"] = {
		label = "ブラッシュストローク迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のブラッシュストローク迷彩",
		client = {
			image = "brushcamo_attachment.png",
		}
	},

	["drill"] = {
		label = "ドリル",
		weight = 20000,
		stack = true,
		close = false,
		description = "本物だ…",
		client = {
			image = "drill.png",
		}
	},

	["walkstick"] = {
		label = "杖",
		weight = 1000,
		stack = true,
		close = true,
		description = "おばあちゃんたちのための杖…ハハ",
		client = {
			image = "walkstick.png",
		}
	},

	["thermalscope_attachment"] = {
		label = "サーマルスコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のサーマルスコープ",
		client = {
			image = "thermalscope_attachment.png",
		}
	},

	["repairkit"] = {
		label = "修理キット",
		weight = 2500,
		stack = true,
		close = true,
		description = "車両を修理するための道具が入った工具箱",
		client = {
			image = "repairkit.png",
		}
	},

	["whiskey"] = {
		label = "ウイスキー",
		weight = 500,
		stack = true,
		close = true,
		description = "喉が渇いたすべての人へ",
		client = {
			image = "whiskey.png",
		}
	},

	["geocamo_attachment"] = {
		label = "ジオメトリック迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のジオメトリック迷彩",
		client = {
			image = "geocamo_attachment.png",
		}
	},

	["smallscope_attachment"] = {
		label = "スモールスコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のスモールスコープ",
		client = {
			image = "smallscope_attachment.png",
		}
	},

	["veh_wheels"] = {
		label = "ホイール",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のホイールをアップグレード",
		client = {
			image = "veh_wheels.png",
		}
	},

	["suppressor_attachment"] = {
		label = "サプレッサー",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のサプレッサー",
		client = {
			image = "suppressor_attachment.png",
		}
	},

	["certificate"] = {
		label = "証明書",
		weight = 0,
		stack = true,
		close = true,
		description = "特定の物の所有を証明する証明書",
		client = {
			image = "certificate.png",
		}
	},

	["weed_nutrition"] = {
		label = "植物用肥料",
		weight = 2000,
		stack = true,
		close = true,
		description = "植物の栄養剤",
		client = {
			image = "weed_nutrition.png",
		}
	},

	["thermite"] = {
		label = "テルミット",
		weight = 1000,
		stack = true,
		close = true,
		description = "すべてを燃やしたくなる時もある",
		client = {
			image = "thermite.png",
		}
	},

	["weed_amnesia"] = {
		label = "アムネジア 2g",
		weight = 200,
		stack = true,
		close = false,
		description = "アムネジア2g入りの大麻袋",
		client = {
			image = "weed_baggy.png",
		}
	},

	["veh_transmission"] = {
		label = "トランスミッション",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のトランスミッションをアップグレード",
		client = {
			image = "veh_transmission.png",
		}
	},

	["snikkel_candy"] = {
		label = "スニッケル",
		weight = 100,
		stack = true,
		close = true,
		description = "おいしいお菓子 :O",
		client = {
			image = "snikkel_candy.png",
		}
	},

	["comp_attachment"] = {
		label = "コンペンセイター",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のコンペンセイター",
		client = {
			image = "comp_attachment.png",
		}
	},

	["tosti"] = {
		label = "グリルチーズサンド",
		weight = 200,
		stack = true,
		close = true,
		description = "おいしく食べられる",
		client = {
			image = "tosti.png",
		}
	},

	["medscope_attachment"] = {
		label = "ミディアムスコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のミディアムスコープ",
		client = {
			image = "medscope_attachment.png",
		}
	},

	["weed_ak47"] = {
		label = "AK47 2g",
		weight = 200,
		stack = true,
		close = false,
		description = "AK47 2g入りの大麻袋",
		client = {
			image = "weed_baggy.png",
		}
	},

	["tablet"] = {
		label = "タブレット",
		weight = 2000,
		stack = true,
		close = true,
		description = "高価なタブレット",
		client = {
			image = "tablet.png",
		}
	},

	["grape"] = {
		label = "ぶどう",
		weight = 100,
		stack = true,
		close = false,
		description = "んー、おいしいぶどう",
		client = {
			image = "grape.png",
		}
	},

	["veh_toolbox"] = {
		label = "工具箱",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両の状態をチェック",
		client = {
			image = "veh_toolbox.png",
		}
	},

	["firstaid"] = {
		label = "救急キット",
		weight = 2500,
		stack = true,
		close = true,
		description = "この救急キットで人を立ち上がらせることができる",
		client = {
			image = "firstaid.png",
		}
	},

	["vodka"] = {
		label = "ウォッカ",
		weight = 500,
		stack = true,
		close = true,
		description = "喉が渇いたすべての人へ",
		client = {
			image = "vodka.png",
		}
	},

	["fat_end_muzzle_brake"] = {
		label = "ファットエンドマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "fat_end_muzzle_brake.png",
		}
	},

	["weed_ogkush"] = {
		label = "OGクッシュ 2g",
		weight = 200,
		stack = true,
		close = false,
		description = "OGクッシュ2g入りの大麻袋",
		client = {
			image = "weed_baggy.png",
		}
	},

	["antipatharia_coral"] = {
		label = "ツノサンゴ",
		weight = 1000,
		stack = true,
		close = true,
		description = "黒サンゴやトゲサンゴとも呼ばれる",
		client = {
			image = "antipatharia_coral.png",
		}
	},

	["lawyerpass"] = {
		label = "弁護士証",
		weight = 0,
		stack = false,
		close = false,
		description = "容疑者の弁護ができることを示す弁護士専用の証明証",
		client = {
			image = "lawyerpass.png",
		}
	},

	["kurkakola"] = {
		label = "コーラ",
		weight = 500,
		stack = true,
		close = true,
		description = "喉が渇いたすべての人へ",
		client = {
			image = "cola.png",
		}
	},
	['handcuffs'] = {
    label = '手錠',
    weight = 200,
    stack = true,
    close = true,
	consume = 0,
	description = "行儀の悪い人がいる時に役立つ。他のことにも使えるかも？",
    client = {
        image = "handcuffs.png",
		export = 'novill-handcuffs.useHandcuffs',
    }
},

	["markedbills"] = {
		label = "マーク付き紙幣",
		weight = 1000,
		stack = false,
		close = true,
		description = "お金？",
		client = {
			image = "markedbills.png",
		}
	},

	["iphone"] = {
		label = "アイフォン",
		weight = 1000,
		stack = true,
		close = true,
		description = "とても高価なスマートフォン",
		client = {
			image = "iphone.png",
		}
	},

	["binoculars"] = {
		label = "双眼鏡",
		weight = 600,
		stack = true,
		close = true,
		description = "こっそり覗き見…",
		client = {
			image = "binoculars.png",
		}
	},

	["xtcbaggy"] = {
		label = "XTCの袋",
		weight = 0,
		stack = true,
		close = true,
		description = "さあ錠剤をキメようぜ",
		client = {
			image = "xtc_baggy.png",
		}
	},

	["weed_whitewidow_seed"] = {
		label = "ホワイトウィドウの種",
		weight = 0,
		stack = true,
		close = false,
		description = "ホワイトウィドウの大麻の種",
		client = {
			image = "weed_seed.png",
		}
	},

	["radioscanner"] = {
		label = "無線スキャナー",
		weight = 1000,
		stack = true,
		close = true,
		description = "これで警察の通報を傍受できる。ただし100%ではない",
		client = {
			image = "radioscanner.png",
		}
	},

	["veh_interior"] = {
		label = "内装",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両の内装をアップグレード",
		client = {
			image = "veh_interior.png",
		}
	},

	["item_bench"] = {
		label = "作業台",
		weight = 15000,
		stack = false,
		close = false,
		description = "アイテムを作るための作業台",
		client = {
			image = "workbench.png",
		}
	},

	["attachment_bench"] = {
		label = "アタッチメント作業台",
		weight = 15000,
		stack = false,
		close = false,
		description = "アタッチメントを作るための作業台",
		client = {
			image = "attworkbench.png",
		}
	},

	["veh_plates"] = {
		label = "ナンバープレート",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のナンバープレートを取り付け",
		client = {
			image = "veh_plates.png",
		}
	},

	["veh_armor"] = {
		label = "装甲",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両の装甲をアップグレード",
		client = {
			image = "veh_armor.png",
		}
	},

	["painkillers"] = {
		label = "鎮痛剤",
		weight = 0,
		stack = true,
		close = true,
		description = "耐えられない痛みに。この薬を飲めばまた気分が良くなる",
		client = {
			image = "painkillers.png",
		}
	},

	["beer"] = {
		label = "ビール",
		weight = 500,
		stack = true,
		close = true,
		description = "冷えたビールに勝るものはない！",
		client = {
			image = "beer.png",
		}
	},

	["twerks_candy"] = {
		label = "トゥワークス",
		weight = 100,
		stack = true,
		close = true,
		description = "おいしいお菓子 :O",
		client = {
			image = "twerks_candy.png",
		}
	},

	["tirerepairkit"] = {
		label = "タイヤ修理キット",
		weight = 1000,
		stack = true,
		close = true,
		description = "タイヤを修理するためのキット",
		client = {
			image = "tirerepairkit.png",
		}
	},

	["newsmic"] = {
		label = "ニュース用マイク",
		weight = 100,
		stack = false,
		close = true,
		description = "ニュース用のマイク",
		client = {
			image = "newsmic.png",
		}
	},

	["goldbar"] = {
		label = "金塊",
		weight = 7000,
		stack = true,
		close = true,
		description = "かなり高価そうだ",
		client = {
			image = "goldbar.png",
		}
	},

	["veh_turbo"] = {
		label = "ターボ",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両にターボを取り付け",
		client = {
			image = "veh_turbo.png",
		}
	},

	["weed_ak47_seed"] = {
		label = "AK47の種",
		weight = 0,
		stack = true,
		close = true,
		description = "AK47の大麻の種",
		client = {
			image = "weed_seed.png",
		}
	},

	["advancedrepairkit"] = {
		label = "高級修理キット",
		weight = 4000,
		stack = true,
		close = true,
		description = "車両を修理するための道具が入った工具箱",
		client = {
			image = "advancedkit.png",
		}
	},

	["weed_skunk_seed"] = {
		label = "スカンクの種",
		weight = 0,
		stack = true,
		close = true,
		description = "スカンクの大麻の種",
		client = {
			image = "weed_seed.png",
		}
	},

	["weed_whitewidow"] = {
		label = "ホワイトウィドウ 2g",
		weight = 200,
		stack = true,
		close = false,
		description = "ホワイトウィドウ2g入りの大麻袋",
		client = {
			image = "weed_baggy.png",
		}
	},

	["coke_brick"] = {
		label = "コカインブロック",
		weight = 1000,
		stack = false,
		close = true,
		description = "コカインの重い包み。主に取引に使われ、場所を取る",
		client = {
			image = "coke_brick.png",
		}
	},

	["zebracamo_attachment"] = {
		label = "ゼブラ迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のゼブラ迷彩",
		client = {
			image = "zebracamo_attachment.png",
		}
	},

	["empty_evidence_bag"] = {
		label = "空の証拠袋",
		weight = 0,
		stack = true,
		close = false,
		description = "血液や薬莢などのDNAを保管するのによく使われる",
		client = {
			image = "evidence.png",
		}
	},

-- [重複のためコメントアウト] 	["lighter"] = {
-- 		label = "ライター",
-- 		weight = 0,
-- 		stack = true,
-- 		close = true,
-- 		description = "大晦日にそばに立つ素敵な火",
-- 		client = {
-- 			image = "lighter.png",
-- 		}
-- 	},

	["grapejuice"] = {
		label = "ぶどうジュース",
		weight = 200,
		stack = true,
		close = false,
		description = "ぶどうジュースは健康にいいらしい",
		client = {
			image = "grapejuice.png",
		}
	},

	["newsbmic"] = {
		label = "ブームマイク",
		weight = 100,
		stack = false,
		close = true,
		description = "使用可能なブームマイク",
		client = {
			image = "newsbmic.png",
		}
	},

	["stickynote"] = {
		label = "付箋",
		weight = 0,
		stack = false,
		close = false,
		description = "何かを覚えておくのに便利なこともある :)",
		client = {
			image = "stickynote.png",
		}
	},

	["firework2"] = {
		label = "ポッペラーズ",
		weight = 1000,
		stack = true,
		close = true,
		description = "花火",
		client = {
			image = "firework2.png",
		}
	},

	["fitbit"] = {
		label = "フィットビット",
		weight = 500,
		stack = false,
		close = true,
		description = "Fitbitが好き",
		client = {
			image = "fitbit.png",
		}
	},

	["aluminumoxide"] = {
		label = "アルミニウム粉末",
		weight = 100,
		stack = true,
		close = false,
		description = "混ぜるための粉末",
		client = {
			image = "aluminumoxide.png",
		}
	},

	["screwdriverset"] = {
		label = "工具セット",
		weight = 1000,
		stack = true,
		close = false,
		description = "ネジを…締めるのにとても便利",
		client = {
			image = "screwdriverset.png",
		}
	},

	["casinochips"] = {
		label = "カジノチップ",
		weight = 0,
		stack = true,
		close = false,
		description = "カジノでギャンブルするためのチップ",
		client = {
			image = "casinochips.png",
		}
	},

	["rolling_paper"] = {
		label = "巻紙",
		weight = 0,
		stack = true,
		close = true,
		description = "タバコや大麻を巻いて吸うための専用の紙",
		client = {
			image = "rolling_paper.png",
		}
	},

	["dendrogyra_coral"] = {
		label = "ハシラサンゴ",
		weight = 1000,
		stack = true,
		close = true,
		description = "ピラーコーラルとも呼ばれる",
		client = {
			image = "dendrogyra_coral.png",
		}
	},

	["weed_purplehaze_seed"] = {
		label = "パープルヘイズの種",
		weight = 0,
		stack = true,
		close = true,
		description = "パープルヘイズの大麻の種",
		client = {
			image = "weed_seed.png",
		}
	},

	["patriotcamo_attachment"] = {
		label = "パトリオット迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のパトリオット迷彩",
		client = {
			image = "patriotcamo_attachment.png",
		}
	},

	["tenkgoldchain"] = {
		label = "10K金のチェーン",
		weight = 2000,
		stack = true,
		close = true,
		description = "10金のチェーン",
		client = {
			image = "10kgoldchain.png",
		}
	},

	["crack_baggy"] = {
		label = "クラックの袋",
		weight = 0,
		stack = true,
		close = true,
		description = "もっと早くハイになれる",
		client = {
			image = "crack_baggy.png",
		}
	},

	["pinger"] = {
		label = "ピンガー",
		weight = 1000,
		stack = true,
		close = true,
		description = "ピンガーとスマホで自分の位置を送信できる",
		client = {
			image = "pinger.png",
		}
	},

	["flashlight_attachment"] = {
		label = "フラッシュライト",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のフラッシュライト",
		client = {
			image = "flashlight_attachment.png",
		}
	},

	["weed_skunk"] = {
		label = "スカンク 2g",
		weight = 200,
		stack = true,
		close = false,
		description = "スカンク2g入りの大麻袋",
		client = {
			image = "weed_baggy.png",
		}
	},

	["bellend_muzzle_brake"] = {
		label = "ベルエンドマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "bellend_muzzle_brake.png",
		}
	},

	["nvscope_attachment"] = {
		label = "暗視スコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用の暗視スコープ",
		client = {
			image = "nvscope_attachment.png",
		}
	},

	["veh_tint"] = {
		label = "スモーク",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両にウィンドウスモークを取り付け",
		client = {
			image = "veh_tint.png",
		}
	},

	["perseuscamo_attachment"] = {
		label = "ペルセウス迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のペルセウス迷彩",
		client = {
			image = "perseuscamo_attachment.png",
		}
	},

	["precision_muzzle_brake"] = {
		label = "プレシジョンマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "precision_muzzle_brake.png",
		}
	},

	["laptop"] = {
		label = "ノートパソコン",
		weight = 4000,
		stack = true,
		close = true,
		description = "高価なノートパソコン",
		client = {
			image = "laptop.png",
		}
	},

	["nitrous"] = {
		label = "ニトロ",
		weight = 1000,
		stack = true,
		close = true,
		description = "加速だ、アクセル全開！ :D",
		client = {
			image = "nitrous.png",
		}
	},

	["ironoxide"] = {
		label = "鉄粉",
		weight = 100,
		stack = true,
		close = false,
		description = "混ぜるための粉末",
		client = {
			image = "ironoxide.png",
		}
	},

	["joint"] = {
		label = "ジョイント",
		weight = 0,
		stack = true,
		close = true,
		description = "シドニーもきっと君を誇りに思うだろう",
		client = {
			image = "joint.png",
		}
	},

	["newscam"] = {
		label = "ニュース用カメラ",
		weight = 100,
		stack = false,
		close = true,
		description = "ニュース用のカメラ",
		client = {
			image = "newscam.png",
		}
	},

	["cryptostick"] = {
		label = "クリプトスティック",
		weight = 200,
		stack = false,
		close = true,
		description = "存在しないお金をなぜ買うんだろう…いくら入っているのかな…？",
		client = {
			image = "cryptostick.png",
		}
	},

	["boomcamo_attachment"] = {
		label = "ブーム迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のブーム迷彩",
		client = {
			image = "boomcamo_attachment.png",
		}
	},

	["skullcamo_attachment"] = {
		label = "スカル迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のスカル迷彩",
		client = {
			image = "skullcamo_attachment.png",
		}
	},

	["cleaningkit"] = {
		label = "洗車キット",
		weight = 250,
		stack = true,
		close = true,
		description = "マイクロファイバークロスと洗剤で車がまたピカピカに！",
		client = {
			image = "cleaningkit.png",
		}
	},

	["weed_ogkush_seed"] = {
		label = "OGクッシュの種",
		weight = 0,
		stack = true,
		close = true,
		description = "OGクッシュの大麻の種",
		client = {
			image = "weed_seed.png",
		}
	},

	["squared_muzzle_brake"] = {
		label = "スクエアードマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "squared_muzzle_brake.png",
		}
	},

	["weed_purplehaze"] = {
		label = "パープルヘイズ 2g",
		weight = 200,
		stack = true,
		close = false,
		description = "パープルヘイズ2g入りの大麻袋",
		client = {
			image = "weed_baggy.png",
		}
	},

	["grip_attachment"] = {
		label = "グリップ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のグリップ",
		client = {
			image = "grip_attachment.png",
		}
	},

	["veh_neons"] = {
		label = "ネオン",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のネオンをアップグレード",
		client = {
			image = "veh_neons.png",
		}
	},

	["heavyarmor"] = {
		label = "ヘビーアーマー",
		weight = 5000,
		stack = true,
		close = true,
		description = "少しの防御なら損はない…よね？",
		client = {
			image = "armor.png",
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500,
			export = 'novill-armor.heavyarmor',
		}
	},

	["veh_exterior"] = {
		label = "外装",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両の外装をアップグレード",
		client = {
			image = "veh_exterior.png",
		}
	},

	["water_bottle"] = {
		label = "ボトル入りの水",
		weight = 500,
		stack = true,
		close = true,
		description = "喉が渇いたすべての人へ",
		client = {
			image = "water_bottle.png",
		}
	},

	["advancedlockpick"] = {
		label = "高級ロックピック",
		weight = 500,
		stack = true,
		close = true,
		description = "よくカギをなくすならとても便利…ビールの栓抜きにも使える",
		client = {
			image = "advancedlockpick.png",
		}
	},

	["split_end_muzzle_brake"] = {
		label = "スプリットエンドマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "split_end_muzzle_brake.png",
		}
	},

	["oxy"] = {
		label = "処方薬オキシ",
		weight = 0,
		stack = true,
		close = true,
		description = "ラベルが剥がされている",
		client = {
			image = "oxy.png",
		}
	},

	["veh_suspension"] = {
		label = "サスペンション",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のサスペンションをアップグレード",
		client = {
			image = "veh_suspension.png",
		}
	},

	["flat_muzzle_brake"] = {
		label = "フラットマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "flat_muzzle_brake.png",
		}
	},

	["advscope_attachment"] = {
		label = "アドバンスドスコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のアドバンスドスコープ",
		client = {
			image = "advscope_attachment.png",
		}
	},

	["filled_evidence_bag"] = {
		label = "証拠袋",
		weight = 200,
		stack = false,
		close = false,
		description = "誰が犯人かを突き止めるための証拠が入った袋 >:(",
		client = {
			image = "evidence.png",
		}
	},

	["samsungphone"] = {
		label = "サムスン S10",
		weight = 1000,
		stack = true,
		close = true,
		description = "とても高価なスマートフォン",
		client = {
			image = "samsungphone.png",
		}
	},

	["digicamo_attachment"] = {
		label = "デジタル迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のデジタル迷彩",
		client = {
			image = "digicamo_attachment.png",
		}
	},

	["jerry_can"] = {
		label = "携行缶 20L",
		weight = 20000,
		stack = true,
		close = true,
		description = "燃料が満タンの缶",
		client = {
			image = "jerry_can.png",
		}
	},

	["firework3"] = {
		label = "ワイプアウト",
		weight = 1000,
		stack = true,
		close = true,
		description = "花火",
		client = {
			image = "firework3.png",
		}
	},

	["sessantacamo_attachment"] = {
		label = "セッサンタノーヴェ迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のセッサンタノーヴェ迷彩",
		client = {
			image = "sessantacamo_attachment.png",
		}
	},

	["police_stormram"] = {
		label = "破壊槌",
		weight = 18000,
		stack = true,
		close = true,
		description = "ドアを破るための便利な道具",
		client = {
			image = "police_stormram.png",
		}
	},

	["luxuryfinish_attachment"] = {
		label = "ラグジュアリー仕上げ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のラグジュアリー仕上げ",
		client = {
			image = "luxuryfinish_attachment.png",
		}
	},

	["armor"] = {
		label = "アーマー",
		weight = 5000,
		stack = true,
		close = true,
		description = "少しの防御なら損はない…よね？",
		client = {
			image = "armor.png",
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500,
			export = 'novill-armor.armor',
		}
	},

	["id_card"] = {
		label = "IDカード",
		weight = 0,
		stack = false,
		close = false,
		description = "身元を証明するための情報がすべて載ったカード",
		client = {
			image = "id_card.png",
		}
	},

	["security_card_01"] = {
		label = "セキュリティカードA",
		weight = 0,
		stack = true,
		close = true,
		description = "セキュリティカード…どこで使うんだろう",
		client = {
			image = "security_card_01.png",
		}
	},

	["tactical_muzzle_brake"] = {
		label = "タクティカルマズルブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のマズルブレーキ",
		client = {
			image = "tactical_muzzle_brake.png",
		}
	},

	["holoscope_attachment"] = {
		label = "ホロスコープ",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のホロスコープ",
		client = {
			image = "holoscope_attachment.png",
		}
	},

	["trojan_usb"] = {
		label = "トロイの木馬USB",
		weight = 0,
		stack = true,
		close = true,
		description = "システムをシャットダウンするための便利なソフトウェア",
		client = {
			image = "usb_device.png",
		}
	},

	["diving_fill"] = {
		label = "ダイビングチューブ",
		weight = 3000,
		stack = false,
		close = true,
		description = "酸素チューブとリブリーザー",
		client = {
			image = "diving_tube.png",
		}
	},

	["printerdocument"] = {
		label = "書類",
		weight = 500,
		stack = false,
		close = true,
		description = "きれいな書類",
		client = {
			image = "printerdocument.png",
		}
	},

	["woodcamo_attachment"] = {
		label = "ウッドランド迷彩",
		weight = 1000,
		stack = true,
		close = true,
		description = "武器用のウッドランド迷彩",
		client = {
			image = "woodcamo_attachment.png",
		}
	},

	["veh_brakes"] = {
		label = "ブレーキ",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のブレーキをアップグレード",
		client = {
			image = "veh_brakes.png",
		}
	},

	["veh_engine"] = {
		label = "エンジン",
		weight = 1000,
		stack = true,
		close = true,
		description = "車両のエンジンをアップグレード",
		client = {
			image = "veh_engine.png",
		}
	},

	["bobby_pin"] = {
		label = "ヘアピン",
		weight = 2500,
		stack = true,
		close = true,
		description = "即席の道具として使える",
		client = {
			image = "bobby_pin.png",
		}
	},

	["tracking_bracelet"] = {
		label = "追跡用ブレスレット",
		weight = 2500,
		stack = true,
		close = true,
		description = "容疑者の追跡に使える",
		client = {
			image = "tracking_bracelet.png",
		}
	},
	
	["medbag"] = {
  label = "医療バッグ",
  weight = 2500,
  stack = false,
  close = true,
  description = "医療用具が入ったバッグです",
  client = {
    image = "medbag.png",
  }
},
["tweezers"] = {
  label = "ピンセット",
  weight = 50,
  stack = false,
  close = true,
  description = "弾を取り出すのに使います",
  client = {
    image = "tweezers.png",
  }
},
["suturekit"] = {
  label = "縫合キット",
  weight = 60,
  stack = false,
  close = true,
  description = "患者の傷を縫合するためのキットです",
  client = {
    image = "suturekit.png",
  }
},
["icepack"] = {
  label = "アイスパック",
  weight = 110,
  stack = false,
  close = true,
  description = "腫れを抑えるために使用します",
  client = {
    image = "icepack.png",
  }
},
["burncream"] = {
  label = "火傷用クリーム",
  weight = 125,
  stack = false,
  close = true,
  description = "火傷のケアに使用します",
  client = {
    image = "burncream.png",
  }
},
["defib"] = {
  label = "除細動器",
  weight = 1120,
  stack = false,
  close = true,
  description = "患者を蘇生させるために使います",
  client = {
    image = "defib.png",
  }
},
["sedative"] = {
  label = "鎮静剤",
  weight = 20,
  stack = false,
  close = true,
  description = "必要に応じて患者を鎮静します",
  client = {
    image = "sedative.png",
  }
},
["morphine30"] = {
  label = "モルヒネ 30MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "morphine30.png",
  }
},
["morphine15"] = {
  label = "モルヒネ 15MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "morphine15.png",
  }
},
["perc30"] = {
  label = "パーコセット 30MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "perc30.png",
  }
},
["perc10"] = {
  label = "パーコセット 10MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "perc10.png",
  }
},
["perc5"] = {
  label = "パーコセット 5MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "perc5.png",
  }
},
["vic10"] = {
  label = "バイコディン 10MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "vic10.png",
  }
},
["vic5"] = {
  label = "バイコディン 5MG",
  weight = 2,
  stack = true,
  close = true,
  combinable = true,
  description = "痛みをコントロールするための規制薬物です",
  client = {
    image = "vic5.png",
  }
},
["medikit"] = {
  label = "医療キット",
  weight = 110,
  stack = true,
  close = true,
  combinable = true,
  description = "負傷者の応急処置キットです",
  client = {
    image = "medikit.png",
  }
},

["crutch"] = {
  label = "松葉杖",
  weight = 650,
  stack = false,
  close = true,
  description = "歩行を補助するための器具です",
  client = {
    image = "crutch.png",
  }
},
["wheelchair"] = {
  label = "車椅子",
  weight = 850,
  stack = false,
  close = true,
  description = "移動を補助するための車椅子です",
  client = {
    image = "wheelchair.png",
  }
},

-- Jim-Mechanic --

["mechanic_tools"] = {
    label = "整備工具", weight = 30, stack = true, close = true, description = "車両の修理に必要",
    client = { image = "mechanic_tools.png", event = "jim-mechanic:client:Repair:Check" }
},
["toolbox"] = {
    label = "工具箱", weight = 50, stack = true, close = true, description = "パフォーマンスパーツの取り外しに必要",
    client = { image = "toolbox.png", event = "jim-mechanic:client:Menu" }
},
["ducttape"] = {
    label = "ダクトテープ", weight = 2, stack = true, close = true, description = "応急修理に便利",
    client = { image = "bodyrepair.png", event = "jim-mechanic:quickrepair" }
},
['mechboard'] = { label = '整備シート', weight = 3, stack = true, close = true,
    buttons = {
        { 	label = 'リストを見る',
            action = function(slot)
                local items = exports.ox_inventory:Search('slots', 'mechboard')
                for _, v in pairs(items) do
                    if (v.slot == slot) then
                        local item = v
                        item.info = item.metadata["info"] or {}
                        TriggerEvent("jim-mechanic:client:giveList", item)
                        exports.ox_inventory:closeInventory()
                        break
                    end
                end
            end
        },
        { 	label = 'パーツリストをコピー',
            action = function(slot)
                local items = exports.ox_inventory:Search('slots', 'mechboard')
                for _, v in pairs(items) do
                    if (v.slot == slot) then
                        lib.setClipboard(v.metadata.info.vehlist)
                        break
                    end
                end
            end
        },
        { 	label = 'ナンバープレートをコピー',
            action = function(slot)
                local items = exports.ox_inventory:Search('slots', 'mechboard')
                for _, v in pairs(items) do
                    if (v.slot == slot) then
                        lib.setClipboard(v.metadata.info.vehplate)
                        break
                    end
                end
            end
        },
        {	label = '車種をコピー',
            action = function(slot)
                local items = exports.ox_inventory:Search('slots', 'mechboard')
                for _, v in pairs(items) do
                    if (v.slot == slot) then
                        lib.setClipboard(v.metadata.info.veh) break
                    end
                end
            end
        },
    },
    client = {
        event = "jim-mechanic:client:giveList"
    }
},
--Performance
["turbo"] = {
    label = "スーパーチャージャーターボ", weight = 80, stack = true, close = true, description = "65mmターボが要らない人なんている？？",
    client = { image = "turbo.png", event = "jim-mechanic:client:applyTurbo", remove = false },
},
["car_armor"] = {
    label = "車両装甲", weight = 250, stack = true, close = true, description = "",
    client = { image = "armour.png", event = "jim-mechanic:client:applyArmour", remove = false },
},
["nos"] = {
    label = "NOSボトル", weight = 30, stack = true, close = true, description = "満タンのNOSボトル",
    client = { image = "nos.png", event = "jim-mechanic:client:applyNOS", },
},
["noscan"] = {
    label = "空のNOSボトル", weight = 15, stack = true, close = true, description = "空になったNOSボトル",
    client = { image = "noscan.png", }
},
["noscolour"] = {
    label = "NOSカラーインジェクター", weight = 3, stack = true, close = true, description = "パージスプレーに色をつけよう",
    client = { image = "noscolour.png", event = "jim-mechanic:client:NOS:rgbORhex", },
},

["engine1"] = {
    label = "ティア1 エンジン", weight = 600, stack = true, close = true, description = "",
    client = { image = "engine1.png",  event = "jim-mechanic:client:applyEngine", level = 0, remove = false },
},
["engine2"] = {
    label = "ティア2 エンジン", weight = 700, stack = true, close = true, description = "",
    client = { image = "engine2.png",  event = "jim-mechanic:client:applyEngine", level = 1, remove = false },
},
["engine3"] = {
    label = "ティア3 エンジン", weight = 800, stack = true, close = true, description = "",
    client = { image = "engine3.png",  event = "jim-mechanic:client:applyEngine", level = 2, remove = false },
},
["engine4"] = {
    label = "ティア4 エンジン", weight = 900, stack = true, close = true, description = "",
    client = { image = "engine4.png",  event = "jim-mechanic:client:applyEngine", level = 3, remove = false },
},
["engine5"] = {
    label = "ティア5 エンジン", weight = 1000, stack = true, close = true, description = "",
    client = { image = "engine5.png",  event = "jim-mechanic:client:applyEngine", level = 4, remove = false },
},

["transmission1"] = {
    label = "ティア1 トランスミッション", weight = 300, stack = true, close = true, description = "",
    client = { image = "transmission1.png",  event = "jim-mechanic:client:applyTransmission", level = 0, remove = false },
},
["transmission2"] = {
    label = "ティア2 トランスミッション", weight = 350, stack = true, close = true, description = "",
    client = { image = "transmission2.png",  event = "jim-mechanic:client:applyTransmission", level = 1, remove = false },
},
["transmission3"] = {
    label = "ティア3 トランスミッション", weight = 400, stack = true, close = true, description = "",
    client = { image = "transmission3.png",  event = "jim-mechanic:client:applyTransmission", level = 2, remove = false },
},
["transmission4"] = {
    label = "ティア4 トランスミッション", weight = 450, stack = true, close = true, description = "",
    client = { image = "transmission4.png",  event = "jim-mechanic:client:applyTransmission", level = 3, remove = false },
},

["brakes1"] = {
    label = "ティア1 ブレーキ", weight = 80, stack = true, close = true, description = "",
    client = { image = "brakes1.png",  event = "jim-mechanic:client:applyBrakes", level = 0, remove = false },
},
["brakes2"] = {
    label = "ティア2 ブレーキ", weight = 90, stack = true, close = true, description = "",
    client = { image = "brakes2.png",  event = "jim-mechanic:client:applyBrakes", level = 1, remove = false },
},
["brakes3"] = {
    label = "ティア3 ブレーキ", weight = 100, stack = true, close = true, description = "",
    client = { image = "brakes3.png",  event = "jim-mechanic:client:applyBrakes", level = 2, remove = false },
},

["suspension1"] = {
    label = "ティア1 サスペンション", weight = 120, stack = true, close = true, description = "",
    client = { image = "suspension1.png", event = "jim-mechanic:client:applySuspension",  level = 0, remove = false },
},
["suspension2"] = {
    label = "ティア2 サスペンション", weight = 140, stack = true, close = true, description = "",
    client = { image = "suspension2.png", event = "jim-mechanic:client:applySuspension", level = 1, remove = false },
},
["suspension3"] = {
    label = "ティア3 サスペンション", weight = 160, stack = true, close = true, description = "",
    client = { image = "suspension3.png", event = "jim-mechanic:client:applySuspension", level = 2, remove = false },
},
["suspension4"] = {
    label = "ティア4 サスペンション", weight = 180, stack = true, close = true, description = "",
    client = { image = "suspension4.png", event = "jim-mechanic:client:applySuspension", level = 3, remove = false },
},
["suspension5"] = {
    label = "ティア5 サスペンション", weight = 200, stack = true, close = true, description = "",
    client = { image = "suspension5.png", event = "jim-mechanic:client:applySuspension", level = 4, remove = false },
},

["bprooftires"] = {
    label = "防弾タイヤ", weight = 150, stack = true, close = true, description = "",
    client = { image = "bprooftires.png", event = "jim-mechanic:client:applyBulletProof", remove = false },
},
["drifttires"] = {
    label = "ドリフトタイヤ", weight = 120, stack = true, close = true, description = "",
    client = { image = "drifttires.png", event = "jim-mechanic:client:applyDrift", remove = false },
},

["oilp1"] = {
    label = "ティア1 オイルポンプ", weight = 20, stack = true, close = true, description = "",
    client = { image = "oilp1.png", event = "jim-mechanic:client:applyExtraPart", level = 1, mod = "oilp", remove = false },
},
["oilp2"] = {
    label = "ティア2 オイルポンプ", weight = 25, stack = true, close = true, description = "",
    client = { image = "oilp2.png", event = "jim-mechanic:client:applyExtraPart", level = 2, mod = "oilp", remove = false },
},
["oilp3"] = {
    label = "ティア3 オイルポンプ", weight = 30, stack = true, close = true, description = "",
    client = { image = "oilp3.png", event = "jim-mechanic:client:applyExtraPart", level = 3, mod = "oilp", remove = false },
},

["drives1"] = {
    label = "ティア1 ドライブシャフト", weight = 60, stack = true, close = true, description = "",
    client = { image = "drives1.png", event = "jim-mechanic:client:applyExtraPart", level = 1, mod = "drives", remove = false },
},
["drives2"] = {
    label = "ティア2 ドライブシャフト", weight = 70, stack = true, close = true, description = "",
    client = { image = "drives2.png", event = "jim-mechanic:client:applyExtraPart", level = 2, mod = "drives", remove = false },
},
["drives3"] = {
    label = "ティア3 ドライブシャフト", weight = 80, stack = true, close = true, description = "",
    client = { image = "drives3.png", event = "jim-mechanic:client:applyExtraPart", level = 3, mod = "drives", remove = false },
},

["cylind1"] = {
    label = "ティア1 シリンダーヘッド", weight = 100, stack = true, close = true, description = "",
    client = { image = "cylind1.png", event = "jim-mechanic:client:applyExtraPart", level = 1, mod = "cylind", remove = false },
},
["cylind2"] = {
    label = "ティア2 シリンダーヘッド", weight = 110, stack = true, close = true, description = "",
    client = { image = "cylind2.png", event = "jim-mechanic:client:applyExtraPart", level = 2, mod = "cylind", remove = false },
},
["cylind3"] = {
    label = "ティア3 シリンダーヘッド", weight = 120, stack = true, close = true, description = "",
    client = { image = "cylind3.png", event = "jim-mechanic:client:applyExtraPart", level = 3, mod = "cylind", remove = false },
},

["cables1"] = {
    label = "ティア1 バッテリーケーブル", weight = 5, stack = true, close = true, description = "",
    client = { image = "cables1.png", event = "jim-mechanic:client:applyExtraPart", level = 1, mod = "cables", remove = false },
},
["cables2"] = {
    label = "ティア2 バッテリーケーブル", weight = 6, stack = true, close = true, description = "",
    client = { image = "cables2.png", event = "jim-mechanic:client:applyExtraPart", level = 2, mod = "cables", remove = false },
},
["cables3"] = {
    label = "ティア3 バッテリーケーブル", weight = 7, stack = true, close = true, description = "",
    client = { image = "cables3.png", event = "jim-mechanic:client:applyExtraPart", level = 3, mod = "cables", remove = false },
},

["fueltank1"] = {
    label = "ティア1 燃料タンク", weight = 100, stack = true, close = true, description = "",
    client = { image = "fueltank1.png", event = "jim-mechanic:client:applyExtraPart", level = 1, mod = "fueltank", remove = false },
},
["fueltank2"] = {
    label = "ティア2 燃料タンク", weight = 110, stack = true, close = true, description = "",
    client = { image = "fueltank2.png", event = "jim-mechanic:client:applyExtraPart", level = 2, mod = "fueltank", remove = false },
},
["fueltank3"] = {
    label = "ティア3 燃料タンク", weight = 120, stack = true, close = true, description = "",
    client = { image = "fueltank3.png", event = "jim-mechanic:client:applyExtraPart", level = 3, mod = "fueltank", remove = false },
},

["antilag"] = {
    label = "アンチラグ", weight = 20, stack = true, close = true, description = "",
    client = { image = "antiLag.png", event = "jim-mechanic:client:applyAntiLag", remove = false },
},

["underglow_controller"] = {
    label = "ネオンコントローラー", weight = 3, stack = true, close = true, description = "",
    client = { image = "underglow_controller.png", event = "jim-mechanic:client:neonMenu", },
},
["headlights"] = {
    label = "キセノンヘッドライト", weight = 15, stack = true, close = true, description = "",
    client = { image = "headlights.png", event = "jim-mechanic:client:applyXenons", },
},

["tint_supplies"] = {
    label = "ウィンドウスモークキット", weight = 8, stack = true, close = true, description = "",
    client = { image = "tint_supplies.png", event = "jim-mechanic:client:Cosmetic:Check", },
},

["customplate"] = {
    label = "カスタムナンバープレート", weight = 5, stack = true, close = true, description = "",
    client = { image = "plate.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["hood"] = {
    label = "車両ボンネット", weight = 150, stack = true, close = true, description = "",
    client = { image = "hood.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["roof"] = {
    label = "車両ルーフ", weight = 150, stack = true, close = true, description = "",
    client = { image = "roof.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["spoiler"] = {
    label = "車両スポイラー", weight = 50, stack = true, close = true, description = "",
    client = { image = "spoiler.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["bumper"] = {
    label = "車両バンパー", weight = 80, stack = true, close = true, description = "",
    client = { image = "bumper.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["skirts"] = {
    label = "車両サイドスカート", weight = 60, stack = true, close = true, description = "",
    client = { image = "skirts.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["exhaust"] = {
    label = "車両マフラー", weight = 70, stack = true, close = true, description = "",
    client = { image = "exhaust.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["seat"] = {
    label = "シートコスメティック", weight = 100, stack = true, close = true, description = "",
    client = { image = "seat.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["rollcage"] = {
    label = "ロールケージ", weight = 200, stack = true, close = true, description = "",
    client = { image = "rollcage.png", event = "jim-mechanic:client:Cosmetic:Check", },
},

["rims"] = {
    label = "カスタムホイールリム", weight = 80, stack = true, close = true, description = "",
    client = { image = "rims.png", event = "jim-mechanic:client:Rims:Check", },
},

["livery"] = {
    label = "ラッピングロール", weight = 20, stack = true, close = true, description = "",
    client = { image = "livery.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["paintcan"] = {
    label = "車両用スプレー缶", weight = 8, stack = true, close = true, description = "",
    client = { image = "spraycan.png", event = "jim-mechanic:client:Paints:Check", },
},
["tires"] = {
    label = "ドリフトスモークタイヤ", weight = 120, stack = true, close = true, description = "",
    client = { image = "tires.png", event = "jim-mechanic:client:Tires:Check", },
},

["horn"] = {
    label = "カスタムクラクション", weight = 5, stack = true, close = true, description = "",
    client = { image = "horn.png", event = "jim-mechanic:client:Cosmetic:Check", },
},

["internals"] = {
    label = "内装コスメティック", weight = 30, stack = true, close = true, description = "",
    client = { image = "internals.png", event = "jim-mechanic:client:Cosmetic:Check", },
},
["externals"] = {
    label = "外装コスメティック", weight = 30, stack = true, close = true, description = "",
    client = { image = "mirror.png", event = "jim-mechanic:client:Cosmetic:Check", },
},

["newoil"] = {
    label = "エンジンオイル", weight = 40, stack = true, close = true, description = "",
    client = { image = "caroil.png", },
},
["sparkplugs"] = {
    label = "スパークプラグ", weight = 2, stack = true, close = true, description = "",
    client = { image = "sparkplugs.png", },
},
["carbattery"] = {
    label = "車用バッテリー", weight = 120, stack = true, close = true, description = "",
    client = { image = "carbattery.png", },
},
["axleparts"] = {
    label = "アクスルパーツ", weight = 50, stack = true, close = true, description = "",
    client = { image = "axleparts.png", },
},
["sparetire"] = {
    label = "スペアタイヤ", weight = 120, stack = true, close = true, description = "",
    client = { image = "sparetire.png", event = "jim-mechanic:client:wheelRepair" },
},

["harness"] = {
    label = "レース用ハーネス", weight = 20, stack = true, close = true, description = "何があっても車内にとどまれるレース用ハーネス",
    client = { image = "harness.png", event = "jim-mechanic:client:applyHarness", remove = false },
},

["manual"] = {
    label = "マニュアルトランスミッション", weight = 250, stack = true, close = true, description = "車両をマニュアル車に変更",
    client = { image = "manual.png", event = "jim-mechanic:client:applyManual", remove = false },
},

["underglow"] = {
    label = "アンダーグローLED", weight = 15, stack = true, close = true, description = "車両にアンダーグローを追加",
    client = { image = "underglow.png", event = "jim-mechanic:client:applyUnderglow", remove = false },
},

["stancerkit"] = {
    label = "スタンサーキット", weight = 40, stack = true, close = true, description = "車両用スタンサーキット",
    client = { image = "stancerkit.png", event = "jim-mechanic:client:stancerMenu", remove = false },
},

["newplate"] = {
    label = "新しいナンバープレート", weight = 2, stack = true, close = true, description = "カスタマイズ可能なナンバープレート",
    client = { image = "newplate.png", event = "jim-mechanic:client:setplate:Menu" }
},

-- Replace these if these are already installed

--["cleaningkit"] = {
--    label = "洗車キット", weight = 0, stack = true, close = true, description = "マイクロファイバークロスと洗剤で、車がピカピカに！",
--    client = { image = "cleaningkit.png", event = "jim-mechanic:client:cleanVehicle"},
--},
--["repairkit"] = {
--    label = "修理キット", weight = 0, stack = true, close = true, description = "車両修理用の工具が入ったツールボックス",
--    client = { image = "repairkit.png", event = "jim-mechanic:vehFailure:RepairVehicle", item = "repairkit", full = false },
--},
--["advancedrepairkit"] = {
--    label = "高度な修理キット", weight = 0, stack = true, close = true, description = "車両修理用の工具が入ったツールボックス",
--    client = { image = "advancedkit.png", event = "jim-mechanic:vehFailure:RepairVehicle", item = "advancedrepairkit", full = true },
--},



['pachinko_ball'] = {
    label = 'パチンコ玉',
    weight = 10,
    stack = true,
    close = false,
    consume = 1,
    description = 'パチンコ台で使用する銀色の玉です。',
    client = {
        image = 'pachinko_ball.png'
    }
},
-- JIM-MINING --
    iron = { label = '鉄', weight = 100, stack = true, description = "何かに使えそうな便利な金属片",
        client = { image = 'iron.png', }
    },
    aluminum = { label = 'アルミニウム', weight = 100, stack = true, description = "何かに使えそうな良質な金属片",
        client = { image = 'aluminum.png', }
    },
    rubber = { label = 'ゴム', weight = 100, stack = true, description = "ゴム。これで自分だけのアヒルちゃんが作れるかも :D",
        client = { image = 'rubber.png', }
    },
    glass = { label = 'ガラス', weight = 100, stack = true, description = "とても割れやすいので注意",
        client = { image = 'glass.png', }
    },
    copper = { label = '銅', weight = 100, stack = true, description = "何かに使えそうな良質な金属片",
        client = { image = 'copper.png', }
    },
    steel = { label = '鋼鉄', weight = 100, stack = true, description = "何かに使えそうな良質な金属片",
        client = { image = 'steel.png', }
    },
    plastic = { label = 'プラスチック', weight = 100, stack = true, description = "リサイクルしよう！ - グレタ・トゥーンベリ 2019",
        client = { image = 'plastic.png', }
    },
    metalscrap = { label = '金属スクラップ', weight = 100, stack = true, description = "これで何か良いものが作れそうだ",
        client = { image = 'metalscrap.png', }
    },

    bottle = { name = "bottle", label = "空き瓶", weight = 10, stack = true,  description = "ガラス瓶",
        client = { image = "bottle.png", }
    },
    can = { name = "can", label = "空き缶", weight = 10, stack = true, description = "空き缶。リサイクルに最適",
        client = { image = "can.png", }
    },

	-- JIM-RECYLE --
    recyclablematerial = { name = "recyclablematerial", label = "リサイクルボックス", stack = true, weight = 100, description = "リサイクル可能な資源が入った箱",
        client = { image = "recyclablematerial.png", }
		},

		
    -- Jim-mining stuff
    stone = { label = "石", weight = 2000, stack = true, close = false, description = "石だ、やったー",
        client = { image = "stone.png", }
    },

    uncut_emerald = { label = "未加工のエメラルド", weight = 100, stack = true, close = false, description = "エメラルドの原石",
        client = { image = "uncut_emerald.png", }
    },
    uncut_ruby = { label = "未加工のルビー", weight = 100, stack = true, close = false, description = "ルビーの原石",
        client = { image = "uncut_ruby.png", }
    },
    uncut_diamond = { label = "未加工のダイヤモンド", weight = 100, stack = true, close = false, description = "ダイヤモンドの原石",
        client = { image = "uncut_diamond.png", }
    },
    uncut_sapphire = { label = "未加工のサファイア", weight = 100, stack = true, close = false, description = "サファイアの原石",
        client = { image = "uncut_sapphire.png", }
    },

    emerald = { label = "エメラルド", weight = 150, stack = true, close = false, description = "輝くエメラルドの宝石！",
        client = { image = "emerald.png", }
    },
    ruby = { label = "ルビー", weight = 150, stack = true, close = false, description = "輝くルビーの宝石！",
        client = { image = "ruby.png", }
    },
-- [重複のためコメントアウト]     diamond = { label = "ダイヤモンド", weight = 150, stack = true, close = false, description = "輝くダイヤモンドの宝石！",
--         client = { image = "diamond.png", }
--     },
    sapphire = { label = "サファイア", weight = 150, stack = true, close = false, description = "輝くサファイアの宝石！",
        client = { image = "sapphire.png", }
    },

    gold_ring = { label = "金の指輪", weight = 200, stack = true, close = false, description = "ダイヤモンドリングなんて大当たりじゃないか！",
        client = { image = "gold_ring.png", }
    },
    diamond_ring = { label = "ダイヤモンドリング", weight = 200, stack = true, close = true, description = "ダイヤモンドリングなんて大当たりじゃないか！",
        client = { image = "diamond_ring.png", }
    },
    ruby_ring = { label = "ルビーの指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "ruby_ring.png", }
    },
    sapphire_ring = { label = "サファイアの指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "sapphire_ring.png", }
    },
    emerald_ring = { label = "エメラルドの指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "emerald_ring.png", }
    },

    silver_ring = { label = "銀の指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "silver_ring.png", }
    },
    diamond_ring_silver = { label = "ダイヤモンドの銀の指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "diamond_ring_silver.png", }
    },
    ruby_ring_silver = { label = "ルビーの銀の指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "ruby_ring_silver.png", }
    },
    sapphire_ring_silver = { label = "サファイアの銀の指輪", weight = 200, stack = true, close = false, description = "きらめくサファイアの指輪。",
        client = { image = "sapphire_ring_silver.png", }
    },
    emerald_ring_silver = { label = "エメラルドの銀の指輪", weight = 200, stack = true, close = false, description = "",
        client = { image = "emerald_ring_silver.png", }
    },
    goldchain = { label = "金のチェーン", weight = 200, stack = true, close = true, description = "金のチェーンなんて大当たりじゃないか！",
        client = { image = "goldchain.png", }
    },
    diamond_necklace = { label = "ダイヤモンドネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "diamond_necklace.png", }
    },
    ruby_necklace = { label = "ルビーネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "ruby_necklace.png", }
    },
    sapphire_necklace = { label = "サファイアネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "sapphire_necklace.png", }
    },
-- [重複のためコメントアウト]     emerald_necklace = { label = "エメラルドネックレス", weight = 200, stack = true, close = false, description = "",
--         client = { image = "emerald_necklace.png", }
--     },

    silverchain = { label = "銀のチェーン", weight = 200, stack = true, close = false, description = "",
        client = { image = "silverchain.png", }
    },
    diamond_necklace_silver = { label = "ダイヤモンドの銀のネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "diamond_necklace_silver.png", }
    },
    ruby_necklace_silver = { label = "ルビーの銀のネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "ruby_necklace_silver.png", }
    },
    sapphire_necklace_silver = { label = "サファイアの銀のネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "sapphire_necklace_silver.png", }
    },
    emerald_necklace_silver = { label = "エメラルドの銀のネックレス", weight = 200, stack = true, close = false, description = "",
        client = { image = "emerald_necklace_silver.png", }
    },

    goldearring = { label = "金のイヤリング", weight = 200, stack = true, close = false, description = "ゴールデンガールのための金のイヤリング",
        client = { image = "gold_earring.png", }
    },
    diamond_earring = { label = "ダイヤモンドのイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "diamond_earring.png", }
    },
    ruby_earring = { label = "ルビーのイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "ruby_earring.png", }
    },
    sapphire_earring = { label = "サファイアのイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "sapphire_earring.png", }
    },
    emerald_earring = { label = "エメラルドのイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "emerald_earring.png", }
    },

    silverearring = { label = "銀のイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "silver_earring.png", }
    },
    diamond_earring_silver = { label = "ダイヤモンドの銀のイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "diamond_earring_silver.png", }
    },
    ruby_earring_silver = { label = "ルビーの銀のイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "ruby_earring_silver.png", }
    },
    sapphire_earring_silver = { label = "サファイアの銀のイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "sapphire_earring_silver.png", }
    },
    emerald_earring_silver = { label = "エメラルドの銀のイヤリング", weight = 200, stack = true, close = false, description = "",
        client = { image = "emerald_earring_silver.png", }
    },
    carbon = { label = "炭素", weight = 1000, stack = true, close = false, description = "基本鉱石の炭素。",
        client = { image = "carbon.png", }
    },
    ironore = { label = "鉄鉱石", weight = 1000, stack = true, close = false, description = "基本鉱石の鉄。",
        client = { image = "ironore.png", }
    },
    copperore = { label = "銅鉱石", weight = 1000, stack = true, close = false, description = "基本鉱石の銅。",
        client = { image = "copperore.png", }
    },
    goldore = { label = "金鉱石", weight = 1000, stack = true, close = false, description = "金鉱石",
        client = { image = "goldore.png", }
    },
    silverore = { label = "銀鉱石", weight = 1000, stack = true, close = false, description = "銀鉱石",
        client = { image = "silverore.png", }
    },
    goldingot = { label = "金のインゴット", weight = 1000, stack = true, close = false, description = "",
        client = { image = "goldingot.png", }
    },
    silveringot = { label = "銀のインゴット", weight = 1000, stack = true, close = false, description = "",
        client = { image = "silveringot.png", }
    },
    pickaxe = { label = "つるはし", weight = 1000, stack = false, close = false, description = "",
        client = { image = "pickaxe.png", }
    },
    miningdrill = { label = "採掘ドリル", weight = 1000, stack = false, close = false, description = "",
        client = { image = "miningdrill.png", }
    },
    mininglaser = { label = "採掘レーザー", weight = 900, stack = false, close = false, description = "",
        client = { image = "mininglaser.png", }
    },
    drillbit = { label = "ドリルビット", weight = 10, stack = true, close = false, description = "",
        client = { image = "drillbit.png", }
    },
    goldpan = { label = "砂金採りの皿", weight = 10, stack = true, close = false, description = "心配しないで、いつか金が見つかるよ！",
        client = { image = "goldpan.png", }
    },
['jammer'] = {
	label = '無線ジャマー',
	weight = 10000,
	allowArmed = true,
	client = {
		event = 'mm_radio:client:usejammer'
	}
},

['radiocell'] = {
	label = '単4電池',
	weight = 1000,
	stack = true,
	allowArmed = true,
	client = {
		event = 'mm_radio:client:recharge'
	}
},
hackphone = { label = "ハッキング用スマホ", weight = 10, stack = true, close = false, description = "どこかの犯罪で使用する道具のようだ・・・",
        client = { image = "hackphone.png", }
    },
hacklaptop = { label = "ハッキング用ノートPC", weight = 10, stack = true, close = false, description = "どこかの犯罪で使用する道具のようだ・・・",
        client = { image = "hack_laptop.png", }
    },
['goldbull'] = {
	label = '金貨',
	weight = 100,
	stack = true,
	close = false,
	description = '黄金で作られた金貨',
},
['rolex'] = {
	label = 'ロレックスの腕時計',
	weight = 30,
	stack = true,
	close = false,
	description = '高級なロレックスの腕時計',
},
['necklace'] = {
	label = 'ネックレス',
	weight = 50,
	stack = true,
	close = false,
	description = '高価なネックレス',
},
['ring'] = {
	label = 'ダイヤモンドリング',
	weight = 30,
	stack = true,
	close = false,
	description = '高価なダイヤモンドの指輪',
},
['pinkdiamond'] = {
	label = 'ピンクダイヤモンド',
	description = '非常に高価なピンクダイヤモンド',
	weight = 1000,
	stack = true,
	close = true
},
['pnecklace'] = {
	label = 'ダイヤモンドネックレス',
	description = '高価なダイヤモンドで装飾された非常に高価なネックレス',
	weight = 1000,
	stack = true,
	close = true
},
['hack_usb'] = {
	label = 'ハッキングUSB',
	description = '機器のハッキングに使用できる便利なツール',
	weight = 1000,
	stack = true,
	close = true
},
['blackjack_table'] = {
    label = 'ブラックジャックテーブル',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['baccarat_table'] = {
    label = 'バカラテーブル',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['poker_table'] = {
    label = 'ポーカーテーブル',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['roulette_table'] = {
    label = 'ルーレットテーブル',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['thunder_roulette_table'] = {
    label = 'サンダールーレットテーブル',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['wheel_machine'] = {
    label = 'ホイール',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['slot_machine'] = {
    label = 'スロットマシン',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},
['horseracing_machine'] = {
    label = '競馬マシン',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},

['metal_detector'] = {
    label = '金属探知機', weight = 2500, stack = false, close = true,
    description = '砂浜に埋まった金属を探せる',
    client = { export = 'nova-metaldetector.useDetector' },
},
-- [重複のためコメントアウト] ['shovel']       = { label = 'シャベル',       weight = 1500, stack = false, description = '穴を掘るのに使う' },
['bottlecap']    = { label = '瓶のフタ',       weight = 10 },
['rusty_can']    = { label = '錆びた缶',       weight = 100 },
['old_coin']     = { label = '古い硬貨',       weight = 20 },
['pocket_watch'] = { label = '懐中時計',       weight = 100 },
['ancient_coin'] = { label = '古代の金貨',     weight = 30 },
['old_note']     = { label = '古びたメモ',     weight = 10, description = '何かの手がかりが書かれている…' },
['new_note']     = { label = '真新しいメモ',   weight = 10, description = '最近誰かが埋めたらしい。インクがまだ新しい…1111と書いてある' },


-- ===== 釣り竿（使うと釣り開始。所持品で右クリック →「カスタマイズ」でリール・エサを設定） =====
['nova_rod_basic'] = {
    label = '竹の釣り竿', weight = 800, stack = false, close = true,
    description = 'まずはこれから。どんな魚も釣れる。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_glass'] = {
    label = 'グラスロッド', weight = 750, stack = false, close = true,
    description = 'しなやかで扱いやすい。湖や川で少し有利。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['nova_rod_carbon'] = {
    label = 'カーボンロッド', weight = 700, stack = false, close = true,
    description = 'ファイトの枠が少し広く、珍しい魚がかかりやすい。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_surf'] = {
    label = '遠投竿', weight = 750, stack = false, close = true,
    description = '遠くまで投げられる。堤防・磯で有利。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_iso'] = {
    label = '磯竿', weight = 750, stack = false, close = true,
    description = '粘り強い胴調子。磯の大物に強い。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['nova_rod_pro'] = {
    label = 'プロ仕様ロッド', weight = 650, stack = false, close = true,
    description = 'アタリが早く、大物との勝負に強い。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_offshore'] = {
    label = 'オフショアロッド', weight = 750, stack = false, close = true,
    description = '船釣り専用の剛竿。沖でとても有利。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_tournament'] = {
    label = 'トーナメントロッド', weight = 750, stack = false, close = true,
    description = '大会で勝つための一本。どこでも強い。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_master'] = {
    label = '名竿「凪」', weight = 750, stack = false, close = true,
    description = '名工の手による逸品。すべての水辺で少し有利。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},
['novill_rod_legend'] = {
    label = '伝説の竿「龍神」', weight = 750, stack = false, close = true,
    description = '主を釣り上げた者だけが手にできる竿。水面に向かって使うと釣りを始める',
    client = { export = 'nova-fishing.useRod' },
    buttons = {
        { label = 'カスタマイズ', action = function(slot) exports['nova-fishing']:openRodCustom(slot) end },
    },
},

-- ===== リール（竿のカスタマイズ画面で竿に装備する） =====
['novill_reel_basic'] = {
    label = '小型スピニングリール', weight = 350, stack = true, close = true,
    description = '最初の一台。少しだけ寄せやすくなる。竿のカスタマイズで装備できる',
},
['novill_reel_spin'] = {
    label = 'スピニングリール', weight = 350, stack = true, close = true,
    description = '定番の一台。扱いやすい。竿のカスタマイズで装備できる',
},
['novill_reel_bait'] = {
    label = 'ベイトリール', weight = 350, stack = true, close = true,
    description = '巻き上げが力強い。竿のカスタマイズで装備できる',
},
['novill_reel_drag'] = {
    label = 'ドラグ強化リール', weight = 350, stack = true, close = true,
    description = '暴れる魚に糸を出して耐える。戻されにくい。竿のカスタマイズで装備できる',
},
['novill_reel_hispeed'] = {
    label = 'ハイギアリール', weight = 350, stack = true, close = true,
    description = '一気に寄せられる高速巻き。竿のカスタマイズで装備できる',
},
['novill_reel_double'] = {
    label = 'ダブルハンドルリール', weight = 350, stack = true, close = true,
    description = '安定した巻き心地。取り込みも楽になる。竿のカスタマイズで装備できる',
},
['novill_reel_electric'] = {
    label = '電動リール', weight = 350, stack = true, close = true,
    description = 'モーターで巻き上げる。深場の大物向け。竿のカスタマイズで装備できる',
},
['novill_reel_biggame'] = {
    label = 'ビッグゲームリール', weight = 350, stack = true, close = true,
    description = 'マグロやカジキと渡り合える剛性。竿のカスタマイズで装備できる',
},
['novill_reel_master'] = {
    label = '匠のリール「疾風」', weight = 350, stack = true, close = true,
    description = '職人が組み上げた至高の一台。竿のカスタマイズで装備できる',
},
['novill_reel_legend'] = {
    label = '伝説のリール「海神」', weight = 350, stack = true, close = true,
    description = '海の神の名を冠したリール。竿のカスタマイズで装備できる',
},

-- ===== エサ（1回の釣りで1つ使う） =====
['novill_bait_worm'] = {
    label = 'ミミズ', weight = 20, stack = true, close = true,
    description = '湖や川の魚によく効く',
},
['nova_bait'] = {
    label = 'エサ', weight = 20, stack = true, close = true,
    description = 'どこでも使える普通のエサ',
},
['novill_bait_krill'] = {
    label = 'オキアミ', weight = 20, stack = true, close = true,
    description = '堤防・磯の定番',
},
['novill_bait_lugworm'] = {
    label = 'イソメ', weight = 20, stack = true, close = true,
    description = '海の根魚がよく食いつく',
},
['novill_bait_shrimp'] = {
    label = '生きエビ', weight = 20, stack = true, close = true,
    description = '海の大物が寄ってくる',
},
['nova_bait_premium'] = {
    label = '高級エサ', weight = 20, stack = true, close = true,
    description = '珍しい魚が寄ってきやすい',
},
['novill_bait_lure'] = {
    label = 'ルアー', weight = 20, stack = true, close = true,
    description = 'フィッシュイーターを誘う疑似餌',
},
['novill_bait_squid'] = {
    label = 'イカの切り身', weight = 20, stack = true, close = true,
    description = '沖の大型魚の好物',
},
['novill_bait_livefish'] = {
    label = '活きアジ', weight = 20, stack = true, close = true,
    description = '泳がせ釣りで超大物を狙う',
},
['novill_bait_special'] = {
    label = '特製練りエサ', weight = 20, stack = true, close = true,
    description = '名人の秘伝の配合',
},
['novill_bait_golden'] = {
    label = '黄金のエサ', weight = 20, stack = true, close = true,
    description = '主すら引き寄せるという幻のエサ',
},

-- ===== 魚・魚拓・剥製 =====
['nova_fish'] = {
    label = '魚', weight = 100, stack = false, close = true,
    description = '魚市場で売れる。剥製工房で魚拓や剥製にできる',
},
['nova_gyotaku'] = {
    label = '魚拓', weight = 300, stack = false, close = true,
    description = '使うと好きな場所に飾れる',
    client = { export = 'nova-fishing.useDisplay' },
},
['nova_mount'] = {
    label = '剥製', weight = 3000, stack = false, close = true,
    description = '使うと好きな場所に飾れる',
    client = { export = 'nova-fishing.useDisplay' },
},


--graffiti

['spray_can'] = {
    label = 'スプレー缶', weight = 300, stack = true, close = true,
    description = '壁にグラフィティを描ける',
    client = { export = 'nova-graffiti.useSpray' },
},
['spray_remover'] = {
    label = '落書き除去剤', weight = 500, stack = true, close = true,
    description = '壁のグラフィティを消せる',
    client = { export = 'nova-graffiti.useRemover' },
},

--ボスタブレット
['boss_tablet'] = {
    label = 'ボスタブレット',
    weight = 500,
    stack = false,
    close = true,
    client = { export = 'nova-bosstablet.useTablet' }
},

--警察タブレット
['police_tablet'] = {
    label = '警察用タブレット',
    weight = 800,
    stack = false,
    close = true,
    description = '罰金・押収・収監の処理と犯罪記録の閲覧ができる',
    client = {
        export = 'nova-policetablet.useTablet',
    },
},

--レストランタブレット
['restaurant_tablet'] = {
       label = '飲食店タブレット', weight = 500, stack = false, close = true,
       client = { export = 'nova-restaurant.openTablet' }
   },
   ['nova_food'] = {
       label = '料理', weight = 250, stack = true, close = true,
       client = { export = 'nova-restaurant.useFood' }
   },
   ['nova_drink'] = {
       label = 'ドリンク', weight = 250, stack = true, close = true,
       client = { export = 'nova-restaurant.useFood' }
   },
   ['nova_dessert'] = {
       label = 'デザート', weight = 250, stack = true, close = true,
       client = { export = 'nova-restaurant.useFood' }
   },
   ['nova_pill'] = {
    label = '錠剤', weight = 20, stack = true, close = true,
    client = { export = 'nova-restaurant.useFood' }
},
['nova_special'] = {
    label = '特殊', weight = 250, stack = true, close = true,
    client = { export = 'nova-restaurant.useFood' }
},

--ハンティング
['hunting_license'] = { label = '狩猟免許', weight = 10, stack = false, close = true, description = 'ライフルの購入に必要な免許' },
['hunting_bait'] = {
    label = '狩猟用ベイト', weight = 300, stack = true, close = true,
    description = '狩猟区域に置くと獲物が寄ってくる',
    client = { export = 'nova-hunting.useBait' },
},

['pelt_deer']   = { label = 'シカの毛皮',     weight = 1500, stack = true },
['meat_venison']= { label = 'シカ肉',         weight = 500,  stack = true },
['deer_antler'] = { label = 'シカの角',       weight = 800,  stack = true },
['pelt_boar']   = { label = 'イノシシの毛皮', weight = 1500, stack = true },
['meat_boar']   = { label = 'イノシシ肉',     weight = 500,  stack = true },
['pelt_coyote'] = { label = 'コヨーテの毛皮', weight = 1000, stack = true },
['pelt_rabbit'] = { label = 'ウサギの毛皮',   weight = 300,  stack = true },
['meat_rabbit'] = { label = 'ウサギ肉',       weight = 300,  stack = true },
['pelt_mtlion'] = { label = 'ピューマの毛皮', weight = 2000, stack = true },
['mtlion_claw'] = { label = 'ピューマの爪',   weight = 100,  stack = true },

--闇オークション
['auction_ticket'] = {
    label = '闇競売 参加券',
    weight = 0,
    stack = false,
    close = true,
},

--トレジャーハント
['treasure_book'] = {
    label = '宝の図鑑',
    weight = 300,
    stack = false,
    close = true,
    description = '海で見つけた宝の記録',
    client = { export = 'nova-treasurehunt.openBook' },
},

--スクラッチ
['scratch_lucky7'] = {
    label = 'スクラッチ（ラッキーセブン）',
    weight = 10,
    stack = true,
    close = true,
    consume = 0,
    description = '削って同じ絵柄が3つそろえば当たり',
    server = { export = 'nova-scratch.useCard' },
},

['scratch_gold'] = {
    label = 'スクラッチ（ゴールドラッシュ）',
    weight = 10,
    stack = true,
    close = true,
    consume = 0,
    description = '削って同じ絵柄が3つそろえば当たり',
    server = { export = 'nova-scratch.useCard' },
},

['scratch_diamond'] = {
    label = 'スクラッチ（ダイヤモンドクラウン）',
    weight = 10,
    stack = true,
    close = true,
    consume = 0,
    description = '削って同じ絵柄が3つそろえば当たり',
    server = { export = 'nova-scratch.useCard' },
},

--ATM強盗
['atm_c4'] = {
    label = 'ATM用爆弾',
    weight = 1500,
    stack = true,
    description = 'ATMに仕掛けて吹き飛ばす',
},
['atm_drill'] = {
    label = 'ドリル',
    weight = 4000,
    stack = false,
    description = 'ATMに穴をあける',
},
['atm_towrope'] = {
    label = '牽引ワイヤー',
    weight = 2000,
    stack = true,
    description = 'ATMと車をつないで引き抜く',
},
['atm_laptop'] = {
    label = 'ハッキング用ノートPC',
    weight = 2000,
    stack = false,
    description = 'ATMに接続して現金を吐き出させる',
},
['atm_torch'] = {
    label = '溶断バーナー',
    weight = 3000,
    stack = false,
    description = 'ATMの扉を焼き切る',
},

--ワイスピ強盗
['tow_wire'] = { label = '牽引ワイヤー', weight = 3000, stack = true, description = '車に繋いで重い物を引きずるためのワイヤー' },

--ドラッグ
['weed_leaf'] = { label = '大麻の葉', weight = 50, stack = true, description = '山で摘める。加工すると売り物になる' },
['coca_leaf'] = { label = 'コカの葉', weight = 50, stack = true, description = '山で摘める。精製すると売り物になる' },
['weed_bag']  = { label = '大麻（小袋）', weight = 20, stack = true, description = '街の人にこっそり売れる' },
['coke_bag']  = { label = 'コカイン（小袋）', weight = 20, stack = true, description = '街の人にこっそり売れる' },
['empty_bag'] = { label = '空の小袋', weight = 5, stack = true },

--ナイトクラブ

['coke'] = {
    label = 'コカイン',
    weight = 1,
    stack = true,
    close = true,
    description = "いけないお薬",
	client = { image = "coke.png", }
},
['expensive_crystals'] = {
    label = '高価なクリスタル',
    weight = 1,
    stack = true,
    close = true,
    description = "高く売れそうなクリスタルだ",
	client = { image = "expensive_crystals.png", }
},
['kq_club_card'] = {
    label = 'クラブカード',
    weight = 1,
    stack = true,
    close = true,
    description = "どこかに入れそうなカードだ",
	client = { image = "kq_club_card.png", }
},
['kq_club_keys'] = {
    label = 'クラブのカギ',
    weight = 1,
    stack = true,
    close = true,
    description = "どこかに入れそうなカギだ",
	client = { image = "kq_club_keys.png", }
},
['kq_hacker_usb'] = {
    label = 'ナイトクラブ用ハッキングusb',
    weight = 1,
    stack = true,
    close = true,
    description = "何かに使いそうだ・・・",
	client = { image = "kq_hacker_usb.png", }
},
['weed'] = {
    label = '葉っぱ',
    weight = 1,
    stack = true,
    close = true,
    description = "危ない葉っぱ",
	client = { image = "weed.png", }
},
['xtc'] = {
    label = 'エクスタシー',
    weight = 1,
    stack = true,
    close = true,
    description = "いけない薬だ",
	client = { image = "xtc.png", }
},
['keys6185'] = {
    label = '6185のカギ',
    weight = 1,
    stack = true,
    close = true,
    description = "どこかに入れそうなカギだ",
	client = { image = "kq_club_keys.png", }
},

--飛行場襲撃
['airfield_gold'] = {
    label = '飛行場で取った金塊',
    weight = 1000,
    stack = true,
    close = true,
    description = '飛行場の貨物機から盗み出した金塊。依頼人に渡せば金になる。',
},

--豪華客船
['yacht_gold'] = {
    label = '豪華客船の金塊',
    weight = 1000,
    stack = true,
    close = true,
    description = '豪華客船から盗み出した金塊。黒スーツの男たちが買い取ってくれる。',
},

['yacht_painting'] = {
    label = '豪華客船の絵画',
    weight = 2500,
    stack = true,
    close = true,
    description = '豪華客船の壁から切り取った絵。黒スーツの男たちが買い取ってくれる。',
},

--カジノHeist
['casino_laptop'] = { label = 'カジノ用ハッキングPC', weight = 1500, stack = true, close = true, description = 'カジノの警備システムに侵入するための端末' },
['casino_drill']  = { label = '金庫ドリル', weight = 3000, stack = false, close = true },
['casino_goldbar'] = { label = '金塊', weight = 1000, stack = true },
['casino_diamond'] = { label = 'ダイヤモンド', weight = 100, stack = true },


--カーゴ強盗
['crime_bag'] = {
    label = '犯罪用カバン',
    weight = 1500,
    stack = true,
    close = true,
    description = '大量の現金や金塊を詰め込める頑丈なカバン。',
},

['cargo_gold'] = {
    label = 'コンテナ船の金塊',
    weight = 1000,
    stack = true,
    close = true,
    description = '沖のコンテナ船から持ち出した金塊。',
},

--カヨペリコ

['cayo_gold'] = {
    label = 'カヨ・ペリコの金塊',
    weight = 1000,
    stack = true,
    close = true,
    description = '依頼人に持っていけば換金してくれる',
},



--食事
['sandwich'] = {
		label = 'サンドイッチ',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'おいしそうなサンドイッチだ'
		},
	},
	['raw_beef'] = {
    label = '生肉', weight = 100, stack = true, close = true,
    description = '調理用の生肉。',
    client = { image = 'raw_beef.png' }
},
['burger_bun'] = {
    label = 'バンズ', weight = 100, stack = true, close = true,
    description = 'ハンバーガー用のバンズ。',
    client = { image = 'burger_bun.png' }
},
['lettuce'] = {
    label = 'レタス', weight = 50, stack = true, close = true,
    description = '新鮮なレタス。',
    client = { image = 'lettuce.png' }
},
['tomato'] = {
    label = 'トマト', weight = 50, stack = true, close = true,
    description = '新鮮なトマト。',
    client = { image = 'tomato.png' }
},
['potato'] = {
    label = 'じゃがいも', weight = 100, stack = true, close = true,
    description = 'フライ用のじゃがいも。',
    client = { image = 'potato.png' }
},
['cooking_oil'] = {
    label = '食用油', weight = 100, stack = true, close = true,
    description = '料理に使う食用油。',
    client = { image = 'cooking_oil.png' }
},
['flour'] = {
    label = '小麦粉', weight = 100, stack = true, close = true,
    description = 'ケーキ作りに使う小麦粉。',
    client = { image = 'flour.png' }
},
['sugar'] = {
    label = '砂糖', weight = 100, stack = true, close = true,
    description = '甘味料として使う砂糖。',
    client = { image = 'sugar.png' }
},
['egg'] = {
    label = '卵', weight = 50, stack = true, close = true,
    description = '料理やケーキに使う卵。',
    client = { image = 'egg.png' }
},
['milk'] = {
    label = '牛乳', weight = 100, stack = true, close = true,
    description = '新鮮な牛乳。',
    client = { image = 'milk.png' }
},
['coffee_beans'] = {
    label = 'コーヒー豆', weight = 50, stack = true, close = true,
    description = '香り高いコーヒー豆。',
    client = { image = 'coffee_beans.png' }
},
['ice'] = {
    label = '氷', weight = 50, stack = true, close = true,
    description = '冷たい氷。',
    client = { image = 'ice.png' }
},
['moonlight_burger'] = {
    label = 'ムーンライトバーガー', weight = 300, stack = true, close = true,
    description = 'Moonlight Café特製バーガー。',
    client = {
        image = 'moonlight_burger.png',
        status = { hunger = 200000 },
        anim = 'eating',
        prop = 'burger',
        usetime = 2500,
        notification = 'おいしそうなCafé特製バーガーだ',
    }
},
['moonlight_fries'] = {
    label = 'フライドポテト', weight = 200, stack = true, close = true,
    description = '揚げたてのフライドポテト。',
    client = {
        image = 'moonlight_fries.png',
        status = { hunger = 200000 },
        anim = 'eating',
        prop = 'burger',
        usetime = 2500,
        notification = 'おいしそうなフライドポテトだ',
    }
},
['moonlight_cake'] = {
    label = '特製ケーキ', weight = 200, stack = true, close = true,
    description = 'Moonlight Café特製ケーキ。',
    client = {
        image = 'moonlight_cake.png',
        status = { hunger = 200000 },
        anim = 'eating',
        prop = 'burger',
        usetime = 2500,
        notification = 'おいしそうな特製ケーキだ',
    }
},
['moonlight_coffee'] = {
    label = 'コーヒー', weight = 150, stack = true, close = true,
    description = '淹れたてのコーヒー。',
    client = {
        image = 'moonlight_coffee.png',
        status = { thirst = 200000 },
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
        usetime = 2500,
        cancel = true,
        notification = '熱くておいしい！',
    }
},
['moonlight_milkshake'] = {
    label = 'ミルクシェイク', weight = 200, stack = true, close = true,
    description = '冷たいミルクシェイク。',
    client = {
        image = 'moonlight_milkshake.png',
        status = { thirst = 200000 },
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
        usetime = 2500,
        cancel = true,
        notification = '冷たくておいしい！',
    }
},

-- ============================================================
-- ox_inventory/data/items.lua の return { } の中に追記
-- ※ bandage は wasabi_ambulance 導入時に追加済みのものをそのまま使う
-- ============================================================

['buff_stew'] = {
    label = '薬膳シチュー',
    weight = 300,
    stack = true,
    close = true,
    consume = 1,
    description = '食べるとしばらくHPが徐々に回復する',
    client = {
        anim = 'eating',
        prop = 'burger',
        usetime = 5000,
        export = 'nova-buffshop.useBuffItem',
    },
    server = { export = 'nova-buffshop.useBuffItem' },
},

['buff_curry'] = {
    label = 'スタミナカレー',
    weight = 300,
    stack = true,
    close = true,
    consume = 1,
    description = '食べるとしばらくスタミナが徐々に回復する',
    client = {
        anim = 'eating',
        prop = 'burger',
        usetime = 5000,
        export = 'nova-buffshop.useBuffItem',
    },
    server = { export = 'nova-buffshop.useBuffItem' },
},

['buff_feather'] = {
    label = 'フェザードリンク',
    weight = 250,
    stack = true,
    close = true,
    consume = 1,
    description = '飲むとしばらく落下ダメージに強くなる',
    client = {
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
        usetime = 3500,
        export = 'nova-buffshop.useBuffItem',
    },
    server = { export = 'nova-buffshop.useBuffItem' },
},

['heal_pill'] = {
    label = '回復錠剤',
    weight = 20,
    stack = true,
    close = true,
    consume = 1,
    description = '体力を中程度回復する。満腹でも服用できる',
    client = {
        anim = { dict = 'mp_suicide', clip = 'pill' },
        usetime = 2000,
        export = 'nova-buffshop.useBuffItem',
    },
    server = { export = 'nova-buffshop.useBuffItem' },
},

--タバコ
['cigarette_carton'] = {
    label = 'タバコ（カートン）',
    weight = 1000,
    stack = true,
    close = true,
    description = '開けるとたばこが20箱入っている',
    server = { export = 'novaciga.cigarette_carton' },
},

['cigarette_pack'] = {
    label = 'たばこ',
    weight = 50,
    stack = true,
    close = true,
    description = '開けるとタバコが20本入っている',
    server = { export = 'novaciga.cigarette_pack' },
},

['cigarette'] = {
    label = 'タバコ',
    weight = 2,
    stack = true,
    close = true,
    description = 'ライターがあれば吸える',
    client = {
        anim = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c', flag = 49 }, -- 歩きながら吸える
        prop = { model = `prop_cs_ciggy_01`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },
        disable = { combat = true },
        usetime = 15000, -- 吸う時間(ms)
        cancel = true,   -- キャンセル可（キャンセル時はタバコは減らない）
    },
    server = { export = 'novaciga.cigarette' },
},

['lighter'] = {
    label = 'ライター',
    weight = 30,
    stack = true,
    close = false,
    description = 'タバコに火をつける',
},

-- 画像を /resources/[ox]/ox_inventory/web/images/ に入れる
-- /resources/[ox]/ox_inventory/data/items.lua の return { } の中に追加

    ['recipe_collection'] = {
        label = 'レシピ集',
        weight = 500,
        stack = true,
        close = true,
        description = 'さまざまなレシピがまとめられた本',
    },

    ['weaponry_enhancer'] = {
        label = '武器術の書 I',
        weight = 500,
        stack = true,
        close = true,
        description = '武器の熟練度が1000ポイント上がる',
    },

    ['portable_chemist'] = {
        label = '化学作業台',
        weight = 500,
        stack = true,
        close = true,
        description = '化学の作業ができる作業台',
    },

    ['portable_chemist_drugs'] = {
        label = '特殊化学作業台',
        weight = 500,
        stack = true,
        close = true,
        description = '特殊な化学の作業ができる作業台',
        client = {
            image = 'portable_chemist.png',
        },
    },

    ['portable_cooking_fireplace'] = {
        label = '焚き火',
        weight = 500,
        stack = true,
        close = true,
        description = '焚き火で料理ができる',
        client = {
            image = 'portable_fireplace.png',
        },
    },

    ['blueprint_pistol'] = {
        label = 'ピストルの設計図',
        weight = 500,
        stack = false,
        close = true,
        description = '銃を作るために必要な知識が書かれている。一度覚えれば十分だ。',
    },

	-- 画像を /resources/[ox]/ox_inventory/web/images/ に入れる
-- /resources/[ox]/ox_inventory/data/items.lua の return { } の中に追加

    ['labor_enhancer'] = {
        label = '労働力 1000',
        weight = 500,
        stack = true,
        close = true,
        description = '労働力が1000ポイント増える',
    },

    ['crowbar'] = {
        label = 'バール',
        weight = 500,
        stack = true,
        close = true,
        description = '何に使うのかわからないバール',
    },

	--アーティファクト
	['cutter'] = {
    label = 'カッター',
    weight = 160,
},
['pogo'] = {
    label = 'ポゴ',
    weight = 160,
},
['diamond'] = {
    label = 'ダイヤモンド',
    weight = 160,
},
['panther'] = {
    label = 'パンサー像',
    weight = 160,
},
['artskull'] = {
    label = 'アートスカル',
    weight = 160,
},
['artegg'] = {
    label = 'アートエッグ',
    weight = 160,
},

--prison

['wood'] = {
    label = '木材',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},

['metal'] = {
    label = '金属',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},

['rope'] = {
    label = 'ロープ',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},

['shovel'] = {
    label = 'シャベル',
    weight = 1,
    stack = true,
    close = true,
    description = nil
},

--サイレンシステム

['kq_emergency_lights_kit'] = {
        label = "緊急灯キット",
        weight = 2000,
        stack = true,
        consume = 0,
        server = {
            export = 'kq_emergency.UseItem',
        },
    },

--ペントハウス？カジノ強盗
["emerald_necklace"] = {
  label = "エメラルドネックレス",
  weight = 200,
  stack = true,
  close = false,
  description = "",
  client = {
   image = "emerald_necklace.png",
  }
},
["x_guitar"] = {
  label = "ギター",
  weight = 5000,
  stack = false,
  close = false,
  description = "音楽機材",
  client = {
    image = "x_guitar.png"
  }
},
["x_musicequipment"] = {
  label = "音楽機材",
  weight = 5000,
  stack = false,
  close = false,
  description = "音楽機材",
  client = {
    image = "x_musicequipment.png"
  }
},

["x_pcequipment"] = {
  label = "パソコン機材",
  weight = 5000,
  stack = false,
  close = false,
  description = "パソコン機材",
  client = {
    image = "x_pcequipment.png"
  }
},

["x_monitor"] = {
  label = "モニター",
  weight = 1000,
  stack = false,
  close = false,
  description = "パソコン用モニター",
  client = {
    image = "x_monitor.png"
  }
},

["x_pantherstatue"] = {
  label = "パンサー像",
  weight = 5000,
  stack = false,
  close = false,
  description = "パンサーの像",
  client = {
    image = "x_pantherstatue.png"
  }
},

["x_watch"] = {
  label = "腕時計",
  weight = 100,
  stack = true,
  close = false,
  description = "腕時計",
  client = {
    image = "x_watch.png"
  }
},

["x_headphones"] = {
  label = "ヘッドホン",
  weight = 100,
  stack = true,
  close = false,
  description = "ただのヘッドホン..",
  client = {
    image = "x_headphones.png"
  }
},

["x_bananatrophy"] = {
  label = "バナナトロフィー",
  weight = 1000,
  stack = false,
  close = false,
  description = "聞かないで..",
  client = {
    image = "x_bananatrophy.png"
  }
},

 ['x_wrench'] = {
        label = "レンチ",
        weight = 250,
        stack = false,
        close = false,
        description = "整備に便利",
        client = {
            image = "x_wrench.png",
        }
    },

    ["giant_gem"] = {
        label = "巨大な宝石",
        weight = 2500,
        stack = false,
        close = false,
        description = "",
        client = {
            image = "giant_gem.png",
        }
    },

    ['x_moneysuitcase'] = {
        label = "現金入りスーツケース",
        weight = 2500,
        stack = false,
        close = false,
        description = "大量の現金が入っている..",
        client = {
            image = "x_moneysuitcase.png",
        }
    },

    ["x_cratejammer"] = {
        label = "X クレートジャマー",
        weight = 300,
        stack = false,
        close = false,
        description = "?????????",
        client = {
            image = "x_cratejammer.png",
        }
    },

    ['casinomaintenancecard'] = {
        label = "カジノ整備用カードキー",
        weight = 100,
        stack = false,
        close = false,
        description = "何に使えるんだろう..",
        client = {
            image = "casinomaintenancecard.png",
        }
    },

    ['casinosecuritycard'] = {
        label = "カジノ警備用カードキー",
        weight = 100,
        stack = false,
        close = false,
        description = "何に使えるんだろう..",
        client = {
            image = "casinosecuritycard.png",
        }
    },

    ['casinovaultcard'] = {
        label = "カジノ金庫カードキー",
        weight = 100,
        stack = false,
        close = false,
        description = "何に使えるんだろう..",
        client = {
            image = "casinovaultcard.png",
        }
    },

    ['casinomanagercard'] = {
        label = "カジノ支配人カードキー",
        weight = 100,
        stack = false,
        close = false,
        description = "何に使えるんだろう..",
        client = {
            image = "casinomanagercard.png",
        }
    },

    ['casinopenthousecard'] = {
        label = "カジノペントハウスカードキー",
        weight = 100,
        stack = false,
        close = false,
        description = "豪華なカードキー..",
        client = {
            image = "casinopenthousecard.png",
        }
    },

    ['managerlaptop'] = {
        label = "支配人のノートPC",
        weight = 100,
        stack = false,
        close = false,
        description = "これで何ができるんだろう..",
        client = {
            image = "managerlaptop.png",
        }
    },

    ['bag'] = {
        label = "バッグ",
        weight = 400,
        stack = false,
        close = false,
        description = "ダッフルバッグ",
        client = {
            image = "bag.png",
        }
    },

    ['glass_cutter'] = {
        label = "ガラスカッター",
        weight = 1000,
        stack = false,
        close = false,
        description = "",
        client = {
            image = "glass_cutter.png",
        }
    },

    ['x_fingerprinttape'] = {
        label = "指紋採取テープ",
        weight = 200,
        stack = false,
        close = false,
        description = "????",
        client = {
            image = "x_fingerprinttape.png",
        }
    },

    ['x_fingerprintbag'] = {
        label = "指紋保管袋",
        weight = 200,
        stack = false,
        close = false,
        description = "????",
        client = {
            image = "x_fingerprintbag.png",
        }
    },

    ['x_phone'] = {
        label = "X フォン",
        weight = 50,
        stack = false,
        close = false,
        description = "?????????",
        client = {
            image = "x_phone.png",
        }
    },

    ['x_device'] = {
        label = "X デバイス",
        weight = 50,
        stack = false,
        close = false,
        description = "?????????",
        client = {
            image = "x_device.png",
        }
    },

    ['x_laptop'] = {
        label = "X ノートPC",
        weight = 50,
        stack = false,
        close = false,
        description = "?????????",
        client = {
            image = "x_laptop.png",
        }
    },

    ['laserdrill'] = {
        label = "レーザードリル",
        weight = 7500,
        stack = false,
        close = true,
        description = "レーザードリル",
        client = {
            image = "laserdrill.png",
        }
    },

    ['x_stethoscope'] = {
        label = "X 聴診器",
        weight = 200,
        stack = false,
        close = false,
        description = "カチッ カチッ",
        client = {
            image = "x_stethoscope.png",
        }
    },

    ["x_painting"] = {
        label = "絵画",
        weight = 200,
        stack = true,
        close = false,
        description = "現代アートの傑作！",
        client = {
                image = "x_painting.png"
        }
    },

    ["x_circuittester"] = {
        label = "X 回路テスター",
        weight = 125,
        stack = false,
        close = false,
        description = "?????????",
        client = {
            image = "x_circuittester.png",
        }
    },

	    ['gasmask'] = {
  label = 'ガスマスク',
  weight = 450,
  stack = false,
  close = true,
  description = "ふぅ..",
  client = {
   event = 'projectx-masks:client:UseGasMask',
  }
 },

 ['nightvision'] = {
  label = '暗視ゴーグル',
  weight = 450,
  stack = false,
  close = true,
  description = "ふぅ..",
  client = {
   event = 'projectx-masks:client:UseNightVision',
  }
 },

 ['clothing_bag'] = {
		label = '衣装バッグ',
		weight = 100,
		stack = true,
		close = true,
		description = '地面に置いて開けると、保存した衣装に着替えられる',
	},





--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  EMS関連の道具

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]

  ['pmediora_tablet'] = {
    label   = '医療端末',
    weight  = 500,
    stack   = false,
    close   = true,
    consume = 0,
    description = '',
    client = {
      export = 'ptech_mediora_core.useTablet',
    },
  },
  ['pmediora_supplybox'] = {
    label = '医療物資',
    weight = 500,
    stack = true,
    close = true,
    consume = 0,
    description = '納品先が指定された医療物資',
    server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
  },
  ['pmediora_specialbox'] = {
    label = '特注医療物資', weight = 500, stack = true, close = true, consume = 0,
    description = '日替わりレシピで作る特注医療物資',
    server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
  },
  ['pmediora_defibrillator'] = {
    label = '除細動器', englishLabel = 'AED', description = '患者の蘇生に使用する',
    weight = 1500, stack = false, buyPrice = nil, sellPrice = nil,
    effect = { type = 'revive' },
  },
  ['pmediora_firstaidkit'] = {
      label = '救急キット', englishLabel = 'First Aid Kit', description = '体力を大幅に回復させる',
      weight = 1000, stack = true, buyPrice = 300000, sellPrice = 60000,
      effect = { type = 'heal', percent = 100 },
  },
  ['pmediora_bandage'] = {
      label = '包帯', englishLabel = 'Bandage', description = '出血を止め、体力を少量回復させる',
      weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
      effect = { type = 'heal', percent = 15, clearBleeding = true },
  },
  ['pmediora_splint'] = {
      label = '副木', englishLabel = 'Splint', description = '骨折した箇所を補強する。治療後15分間は再発しやすくなる',
      weight = 500, stack = true, buyPrice = 150000, sellPrice = 30000,
      effect = { type = 'treat_injury', injury = 'fracture', applyState = 'splint', stateDuration = 900 },
  },
  ['pmediora_icepack'] = {
      label = '冷却パック', englishLabel = 'Ice Pack', description = '患部を冷やし、打撲の症状を抑える',
      weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
      effect = { type = 'treat_injury', injury = 'beat' },
  },
  ['pmediora_bulletextractionkit'] = {
      label = '摘出キット', englishLabel = 'Bullet Extraction Kit', description = '患部から弾丸を安全に摘出する',
      weight = 500, stack = true, buyPrice = 100000, sellPrice = 20000,
      effect = { type = 'treat_injury', injury = 'shot', clearBleeding = true, healPercent = 15 },
  },
  ['pmediora_surgicalforceps'] = {
      label = 'ピンセット', englishLabel = 'Surgical Forceps', description = '患部から弾丸を取り除くが、たまに出血してしまう',
      weight = 150, stack = true, buyPrice = 50000, sellPrice = 10000,
      effect = { type = 'treat_injury', injury = 'shot', bleedingChance = 0.30 },
  },
  ['pmediora_suturekit'] = {
      label = '縫合キット', englishLabel = 'Suture Kit', description = '患部を安全に縫合する',
      weight = 300, stack = true, buyPrice = 100000, sellPrice = 20000,
      effect = { type = 'treat_injury', injury = 'stabbed', clearBleeding = true, healPercent = 15 },
  },
  ['pmediora_needleandthread'] = {
      label = '針と糸', englishLabel = 'Needle and Thread', description = '患部を縫い付けるが、たまに出血してしまう',
      weight = 100, stack = true, buyPrice = 50000, sellPrice = 10000,
      effect = { type = 'treat_injury', injury = 'stabbed', bleedingChance = 0.30 },
  },
  ['pmediora_burncream'] = {
      label = '火傷クリーム', englishLabel = 'Burn Cream', description = '火傷の炎症を抑える薬',
      weight = 150, stack = true, buyPrice = 100000, sellPrice = 20000,
      effect = { type = 'treat_injury', injury = 'burned' },
  },
  ['pmediora_herb'] = {
      label = '薬草', englishLabel = 'EMS Herb', description = '摘んできた薬草。雑草ではない',
      weight = 50, stack = true, usable = false,
  },
  ['pmediora_water'] = {
      label = '水', englishLabel = 'EMS Water', description = '汲んだ水。飲むのはちょっと',
      weight = 500, stack = true, usable = false,
  },
  ['pmediora_purifiedwater'] = {
      label = '精製水', englishLabel = 'EMS Purified Water', description = '精製された水。医療に使用できる',
      weight = 500, stack = true, usable = false,
  },





--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  タバコ屋関連の道具

_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]


  ['ptech_botanica_hokuto_carton'] = {
    label = 'HOKUTO カートン', weight = 140, stack = false, close = true, consume = 0,
    client = { export = 'ptech_botanica_tobacco.unpackCarton' },
    description = 'HOKUTOの煙草が5箱入ったカートン。',
  },
  ['ptech_botanica_hokuto_box'] = {
    label = 'HOKUTO', weight = 28, stack = false, close = true, consume = 0,
    client = { export = 'ptech_botanica_tobacco.useCigaretteBox' },
    description = '全10本。使用するたびに1本消費する。',
  },
  ['ptech_botanica_archimedes_carton'] = {
    label = 'ARCHIMEDES カートン', weight = 140, stack = false, close = true, consume = 0,
    client = { export = 'ptech_botanica_tobacco.unpackCarton' },
    description = 'ARCHIMEDESの煙草が5箱入ったカートン。',
  },
  ['ptech_botanica_archimedes_box'] = {
    label = 'ARCHIMEDES', weight = 28, stack = false, close = true, consume = 0,
    client = { export = 'ptech_botanica_tobacco.useCigaretteBox' },
    description = '全10本。使用するたびに1本消費する。',
  },
  ['ptech_botanica_disposable_lighter'] = {
    label = '使い捨てライター', weight = 25, stack = false, close = true, consume = 0,
    description = '20回点火できる使い捨てライター。',
  },--[[_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/]]





--カルテル

['blood_x'] = {
    label = 'ブラッドX',
    weight = 100,
    stack = true,
    close = true,
    consume = 1,
    description = '体力とアーマーを回復する特殊な薬',
    client = {
        export = 'novill_cartel_drugs.useDrug'
    },
},

['overdrive'] = {
    label = 'オーバードライブ',
    weight = 100,
    stack = true,
    close = true,
    consume = 1,
    description = '使用すると足が速くなる特殊な薬',
    client = {
        export = 'novill_cartel_drugs.useDrug'
    },
},


['iron_heart'] = {
    label = 'アイアンハート',
    weight = 100,
    stack = true,
    close = true,
    consume = 1,
    description = '体力が回復する特殊な薬',
    client = {
        export = 'novill_cartel_drugs.useDrug'
    },
},


['nightmare'] = {
    label = 'ナイトメア',
    weight = 100,
    stack = true,
    close = true,
    consume = 1,
    description = '特殊な視覚演出を発生させる特殊な薬',
    client = {
        export = 'novill_cartel_drugs.useDrug',
    },
},


['iron_armor'] = {
    label = 'アイアンアーマー',
    weight = 100,
    stack = true,
    close = true,
    consume = 1,
    description = 'アーマーが回復する特殊な薬',
    client = {
        export = 'novill_cartel_drugs.useDrug'
    },
},

['stamina_x'] = {
    label = 'スタミナX',
    weight = 100,
    stack = true,
    close = true,
    consume = 1,
    description = '一定時間、持久力が減らない特殊な薬',
    client = {
        export = 'novill_cartel_drugs.useDrug',
    },
},

['novill_recipe_memo'] = {
    label = 'レシピのメモ',
    weight = 10,
    stack = false,
    close = true,
    description = '薬の材料が少しだけ書かれたメモ',
    client = { export = 'novill-drugconvoy.useRecipeMemo' },
},

['novill_heli_tablet'] = {
    label = 'ヘリブースティング用タブレット',
    weight = 500,
    stack = false,
    close = true,
    client = {
        export = 'novill-heliboost.useTablet',
    },
},


}