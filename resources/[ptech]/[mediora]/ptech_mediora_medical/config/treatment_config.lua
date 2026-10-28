TreatmentConfig = {
  -- Wasabi Ambulance v1 の傷分類をそのまま治療画面の基本分類として扱う。
  -- Wasabi 本体のアイテム定義・使用処理は変更しない。
  -- MedioraItems に定義した専用物資だけを、Mediora の治療画面で消費する。
  Treatments = {
    shot = {
      label = '銃創処置',
      item = 'ptech_mediora_tweezers',
      wasabiInjury = 'shot',
    },
    stabbed = {
      label = '刺創処置',
      item = 'ptech_mediora_suturekit',
      wasabiInjury = 'stabbed',
    },
    beat = {
      label = '打撲処置',
      item = 'ptech_mediora_icepack',
      wasabiInjury = 'beat',
    },
    burned = {
      label = '熱傷処置',
      item = 'ptech_mediora_burncream',
      wasabiInjury = 'burned',
    },
  },
}
