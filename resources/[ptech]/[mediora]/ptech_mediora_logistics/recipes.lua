-- 日替わり特注レシピ。日付の切替と特注ボーナスは日本時間で判定する。
Config.SpecialCarton = {
  timezoneOffsetHours = 9, -- daily recipe/premium rollover in Japan time
  recipes = {
    {
      id             = 'trauma_pack',
      label          = '外傷処置セット',
      targetHospital = 'pillbox',
      ingredients = {
        pmediora_bandage = 3,
        pmediora_surgicalforceps = 1,
      },
    },
    {
      id = 'burn_pack',
      label          = '火傷処置セット',
      targetHospital = 'sandy_shores',
      ingredients = {
        pmediora_burncream = 2,
        pmediora_icepack = 1,
      },
    },
    {
      id = 'wound_pack',
      label          = '縫合処置セット',
      targetHospital = 'paleto_bay',
      ingredients = {
        pmediora_suturekit = 1,
        pmediora_bandage = 2,
      },
    },
  },
}

-- 通常の医療道具のクラフトレシピ
Config.CraftingRecipes = {
  {
    id          = 'first_aid_kit',
    label       = '救急キット',
    output      = 'pmediora_firstaidkit',
    ingredients = { pmediora_herb = 5, cloth = 5, glass = 2 },
  },
  {
    id          = 'bandage',
    label       = '包帯',
    output      = 'pmediora_bandage',
    ingredients = { pmediora_herb = 1, cloth = 2 },
  },
  {
    id          = 'splint',
    label       = '保護ギプス',
    output      = 'pmediora_protectivecast',
    ingredients = { plastic = 4 },
  },
  {
    id          = 'ice_pack',
    label       = '冷却パック',
    output      = 'pmediora_icepack',
    ingredients = { pmediora_purifiedwater = 2, cloth = 3 },
  },
  {
    id          = 'bullet_extraction_kit',
    label       = '摘出キット',
    output      = 'pmediora_bulletextractionkit',
    ingredients = {
      pmediora_surgicalforceps = 1,
      pmediora_bandage = 1,
      pmediora_purifiedwater = 1,
    },
  },
  {
    id          = 'surgical_forceps',
    label       = 'ピンセット',
    output      = 'pmediora_surgicalforceps',
    ingredients = { aluminum = 3 },
  },
  {
    id          = 'suture_kit',
    label       = '縫合キット',
    output      = 'pmediora_suturekit',
    ingredients = {
      pmediora_needleandthread = 1,
      pmediora_bandage = 1,
      pmediora_purifiedwater = 1,
    },
  },
  {
    id          = 'needle_and_thread',
    label       = '針と糸',
    output      = 'pmediora_needleandthread',
    ingredients = { aluminum = 2, cloth = 1 },
  },
  {
    id          = 'burn_cream',
    label       = '火傷クリーム',
    output      = 'pmediora_burncream',
    ingredients = { pmediora_herb = 2, pmediora_purifiedwater = 1 },
  },
}
