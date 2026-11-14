
Config.Items = {
  ['pmediora_supplybox'] = {
    label = '医療物資',
    description = '',
    weight = 500, stack = true, close = true, consume = 0,
    server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_logistics/install/images/pmediora_supplybox.png' },
  },
  ['pmediora_specialbox'] = {
    label = '特注医療物資',
    description = '',
    weight = 500, stack = true, close = true, consume = 0,
    server = { export = 'ptech_mediora_logistics.openDeliveryBox' },
    client = { image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_logistics/install/images/pmediora_specialbox.png' },
  },
}
