-- 日替わり特注レシピ。日付の切替と特注ボーナスは日本時間で判定する。
Config.SpecialCarton = {
  timezoneOffsetHours = 9, -- daily recipe/premium rollover in Japan time
  recipes = {
    {
      id             = 'trauma_pack',
      label          = '外傷処置セット',
      targetHospital = 'pillbox',
      ingredients = {
        ptech_medical_bandage = 3,
        ptech_medical_surgical_forceps = 1,
      },
    },
    {
      id = 'burn_pack',
      label          = '火傷処置セット',
      targetHospital = 'sandy_shores',
      ingredients = {
        ptech_medical_burn_cream = 2,
        ptech_medical_ice_pack = 1,
      },
    },
    {
      id = 'wound_pack',
      label          = '縫合処置セット',
      targetHospital = 'paleto_bay',
      ingredients = {
        ptech_medical_suture_kit = 1,
        ptech_medical_bandage = 2,
      },
    },
  },
}

-- 通常の医療道具のクラフトレシピ
Config.CraftingRecipes = {
  {
    id          = 'first_aid_kit',
    label       = '救急キット',
    output      = 'ptech_medical_first_aid_kit',
    ingredients = { ptech_medical_herb = 5, cloth = 5, glass = 2 },
  },
  {
    id          = 'bandage',
    label       = '包帯',
    output      = 'ptech_medical_bandage',
    ingredients = { ptech_medical_herb = 1, cloth = 2 },
  },
  {
    id          = 'splint',
    label       = '副木',
    output      = 'ptech_medical_splint',
    ingredients = { plastic = 4 },
  },
  {
    id          = 'ice_pack',
    label       = '冷却パック',
    output      = 'ptech_medical_ice_pack',
    ingredients = { ptech_medical_purified_water = 2, cloth = 3 },
  },
  {
    id          = 'bullet_extraction_kit',
    label       = '摘出キット',
    output      = 'ptech_medical_bullet_extraction_kit',
    ingredients = {
      ptech_medical_surgical_forceps = 1,
      ptech_medical_bandage = 1,
      ptech_medical_purified_water = 1,
    },
  },
  {
    id          = 'surgical_forceps',
    label       = 'ピンセット',
    output      = 'ptech_medical_surgical_forceps',
    ingredients = { aluminum = 3 },
  },
  {
    id          = 'suture_kit',
    label       = '縫合キット',
    output      = 'ptech_medical_suture_kit',
    ingredients = {
      ptech_medical_needle_and_thread = 1,
      ptech_medical_bandage = 1,
      ptech_medical_purified_water = 1,
    },
  },
  {
    id          = 'needle_and_thread',
    label       = '針と糸',
    output      = 'ptech_medical_needle_and_thread',
    ingredients = { aluminum = 2, cloth = 1 },
  },
  {
    id          = 'burn_cream',
    label       = '火傷クリーム',
    output      = 'ptech_medical_burn_cream',
    ingredients = { ptech_medical_herb = 2, ptech_medical_purified_water = 1 },
  },
}
