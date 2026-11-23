-- NOVILL: 日本語ロケール
Locales["ja"] = {
    UI = {
        modal = {
            save = {
                title = "変更を保存",
                description = "この見た目で保存しますか？"
            },
            exit = {
                title = "編集を終了",
                description = "変更は保存されません"
            },
            accept = "はい",
            decline = "いいえ"
        },
        ped = {
            title = "キャラクターモデル",
            model = "モデル"
        },
        headBlend = {
            title = "遺伝",
            shape = {
                title = "顔",
                firstOption = "父",
                secondOption = "母",
                mix = "配合"
            },
            skin = {
                title = "肌",
                firstOption = "父",
                secondOption = "母",
                mix = "配合"
            },
            race = {
                title = "人種",
                shape = "形",
                skin = "肌",
                mix = "配合"
            }
        },
        faceFeatures = {
            title = "顔の特徴",
            nose = {
                title = "鼻",
                width = "幅",
                height = "高さ",
                size = "大きさ",
                boneHeight = "鼻骨の高さ",
                boneTwist = "鼻骨の曲がり",
                peakHeight = "鼻先の高さ"
            },
            eyebrows = {
                title = "眉",
                height = "高さ",
                depth = "奥行き"
            },
            cheeks = {
                title = "頬",
                boneHeight = "頬骨の高さ",
                boneWidth = "頬骨の幅",
                width = "幅"
            },
            eyesAndMouth = {
                title = "目と口",
                eyesOpening = "目の開き",
                lipsThickness = "唇の厚さ"
            },
            jaw = {
                title = "あご",
                width = "幅",
                size = "大きさ"
            },
            chin = {
                title = "下あご",
                lowering = "下がり具合",
                length = "長さ",
                size = "大きさ",
                hole = "割れあご"
            },
            neck = {
                title = "首",
                thickness = "太さ"
            }
        },
        headOverlays = {
            title = "外見",
            hair = {
                title = "髪",
                style = "髪型",
                color = "髪色",
                highlight = "ハイライト",
                texture = "テクスチャ",
                fade = "フェード"
            },
            opacity = "濃さ",
            style = "スタイル",
            color = "色",
            secondColor = "サブカラー",
            blemishes = "シミ・傷",
            beard = "ひげ",
            eyebrows = "眉毛",
            ageing = "老け具合",
            makeUp = "メイク",
            blush = "チーク",
            complexion = "肌の質感",
            sunDamage = "日焼けダメージ",
            lipstick = "口紅",
            moleAndFreckles = "ほくろ・そばかす",
            chestHair = "胸毛",
            bodyBlemishes = "体のシミ・傷",
            eyeColor = "目の色"
        },
        components = {
            title = "服",
            drawable = "種類",
            texture = "柄",
            mask = "マスク",
            upperBody = "手・腕",
            lowerBody = "ズボン",
            bags = "バッグ・パラシュート",
            shoes = "靴",
            scarfAndChains = "スカーフ・ネックレス",
            shirt = "インナー",
            bodyArmor = "防弾ベスト",
            decals = "デカール",
            jackets = "上着",
            head = "頭"
        },
        props = {
            title = "アクセサリー",
            drawable = "種類",
            texture = "柄",
            hats = "帽子・ヘルメット",
            glasses = "メガネ",
            ear = "イヤリング",
            watches = "腕時計",
            bracelets = "ブレスレット"
        },
        tattoos = {
            title = "タトゥー",
            items = {
                ZONE_TORSO = "胴体",
                ZONE_HEAD = "頭",
                ZONE_LEFT_ARM = "左腕",
                ZONE_RIGHT_ARM = "右腕",
                ZONE_LEFT_LEG = "左脚",
                ZONE_RIGHT_LEG = "右脚"
            },
            apply = "入れる",
            delete = "消す",
            deleteAll = "タトゥーをすべて消す",
            opacity = "濃さ"
        }
    },
    outfitManagement = {
        title = "服装管理",
        jobText = "ジョブの服装を管理",
        gangText = "ギャングの服装を管理"
    },
    cancelled = {
        title = "編集をキャンセル",
        description = "変更は保存されませんでした"
    },
    outfits = {
        import = {
            title = "服装コードを入力",
            menuTitle = "服装を読み込む",
            description = "共有コードから服装を読み込みます",
            name = {
                label = "服装の名前",
                placeholder = "お気に入りの服",
                default = "読み込んだ服装"
            },
            code = {
                label = "服装コード"
            },
            success = {
                title = "服装を読み込みました",
                description = "服装メニューから着替えられます"
            },
            failure = {
                title = "読み込み失敗",
                description = "服装コードが正しくありません"
            }
        },
        generate = {
            title = "服装コードを発行",
            description = "共有用の服装コードを発行します",
            failure = {
                title = "エラーが発生しました",
                description = "服装コードの発行に失敗しました"
            },
            success = {
                title = "服装コードを発行しました",
                description = "あなたの服装コードはこちら"
            }
        },
        save = {
            menuTitle = "今の服装を保存",
            menuDescription = "今の服装を %s の服装として保存します",
            description = "今の服装を保存します",
            title = "服装に名前を付ける",
            managementTitle = "管理用服装の詳細",
            name = {
                label = "服装の名前",
                placeholder = "かっこいい服"
            },
            gender = {
                label = "性別",
                male = "男性",
                female = "女性"
            },
            rank = {
                label = "必要な最低ランク"
            },
            failure = {
                title = "保存失敗",
                description = "同じ名前の服装がすでにあります"
            },
            success = {
                title = "保存完了",
                description = "服装「%s」を保存しました"
            }
        },
        update = {
            title = "服装を上書き",
            description = "今の服装で保存済みの服装を上書きします",
            failure = {
                title = "上書き失敗",
                description = "その服装は存在しません"
            },
            success = {
                title = "上書き完了",
                description = "服装「%s」を上書きしました"
            }
        },
        change = {
            title = "服装を変更",
            description = "保存済みの %s の服装から選びます",
            pDescription = "保存済みの服装から選びます",
            failure = {
                title = "エラーが発生しました",
                description = "その服装にはベースとなる見た目が保存されていません",
            }
        },
        delete = {
            title = "服装を削除",
            description = "保存済みの %s の服装を削除します",
            mDescription = "保存済みの服装を削除します",
            item = {
                title = "「%s」を削除",
                description = "モデル: %s%s"
            },
            success = {
                title = "削除完了",
                description = "服装を削除しました"
            },
            management = {
                success = {
                    title = "削除完了",
                    description = "管理用の服装を削除しました"
                }
            }
        },
        manage = {
            title = "👔 | %s の服装を管理"
        }
    },
    jobOutfits = {
        title = "仕事着",
        description = "仕事着の中から選びます"
    },
    menu = {
        returnTitle = "戻る",
        title = "更衣室",
        outfitsTitle = "保存した服装",
        clothingShopTitle = "服屋",
        barberShopTitle = "床屋",
        tattooShopTitle = "タトゥーショップ",
        surgeonShopTitle = "整形外科"
    },
    clothing = {
        title = "服を買う - $%d",
        titleNoPrice = "服を着替える",
        options = {
            title = "👔 | 服屋のメニュー",
            description = "たくさんの服から選べます"
        },
        outfits = {
            title = "👔 | 服装メニュー",
            civilian = {
                title = "私服",
                description = "私服に着替えます"
            }
        }
    },
    commands = {
        reloadskin = {
            title = "キャラクターの見た目を再読み込み",
            failure = {
                title = "エラー",
                description = "今は reloadskin を使えません"
            }
        },
        clearstuckprops = {
            title = "体にくっついたままの小物をすべて外す",
            failure = {
                title = "エラー",
                description = "今は clearstuckprops を使えません"
            }
        },
        pedmenu = {
            title = "見た目編集メニューを開く / 渡す",
            failure = {
                title = "エラー",
                description = "そのプレイヤーはオンラインではありません"
            }
        },
        joboutfits = {
            title = "ジョブの服装メニューを開く"
        },
        gangoutfits = {
            title = "ギャングの服装メニューを開く"
        },
        bossmanagedoutfits = {
            title = "ボス管理の服装メニューを開く"
        }
    },
    textUI = {
        clothing = "服屋 - 料金: $%d",
        barber = "床屋 - 料金: $%d",
        tattoo = "タトゥーショップ - 料金: $%d",
        surgeon = "整形外科 - 料金: $%d",
        clothingRoom = "更衣室",
        playerOutfitRoom = "服装"
    },
    migrate = {
        success = {
            title = "完了",
            description = "移行が完了しました。%s 件のスキンを移行しました",
            descriptionSingle = "スキンを移行しました"
        },
        skip = {
            title = "お知らせ",
            description = "スキンをスキップしました"
        },
        typeError = {
            title = "エラー",
            description = "種類が正しくありません"
        }
    },
    newCharacter = {
        title = "キャラクター作成",
        description = "%s 秒後にキャラクターの見た目の作成が始まります"
    },
    shop = {
        noMoney = {
            title = "お店に入れません",
            description = "現金が足りません。$%s 必要です"
        }
    },
    shopNames = {
        clothing = "服屋",
        barber = "床屋",
        tattoo = "タトゥーショップ",
        surgeon = "整形外科"
    },
    purchase = {
        tattoo = {
            success = {
                title = "購入完了",
                description = "タトゥー「%s」を $%s で入れました"
            },
            failure = {
                title = "タトゥーを入れられません",
                description = "お金が足りません！"
            }
        },
        store = {
            success = {
                title = "支払い完了",
                description = "$%s を支払いました（%s）"
            },
            failure = {
                title = "不正操作",
                description = "お金が足りないのに購入しようとしました"
            }
        }
    }
}
