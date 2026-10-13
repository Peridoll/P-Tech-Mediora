Config = {
  Jobs = { ambulance = 0 }, RequireDuty = true,
  Location = vec3(309.15, -585.30, 43.28), Distance = 3.0,
  -- Inventory owned by player for v0.1. Shared hospital stock is an optional future adapter.
  Recipes = {
    bandage = { label = '包帯', ingredients = { ptech_pharma_base = 2 }, output = 'bandage', quantity = 1 },
    medkit = { label = '医療キット', ingredients = { ptech_pharma_base = 5 }, output = 'medkit', quantity = 1 }
  },
}
