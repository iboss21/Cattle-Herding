Config = {}

-- HUD/UI Settings
Config.EnableHUD = true
Config.EnableUI = true
Config.HUDPosition = {x = 0.9, y = 0.8}

-- Cattle Settings
Config.CattleModels = {
    'A_C_Cow',
    'A_C_Bull_01',
    'A_C_Ox_01'
}

-- Herding Settings
Config.HerdingRadius = 50.0
Config.HerdingSpeed = 2.0
Config.MaxHerdSize = 10
Config.HerdingXPPerCattle = 5

-- Buying and Selling Locations
Config.CattleShops = {
    {
        name = "Valentine Livestock",
        coords = vector3(-378.95, 785.61, 116.18),
        blip = true
    },
    {
        name = "Emerald Ranch Livestock",
        coords = vector3(1424.07, 365.84, 89.88),
        blip = true
    },
    {
        name = "Blackwater Livestock",
        coords = vector3(-868.52, -1366.52, 43.59),
        blip = true
    }
}

-- Dynamic Pricing System
Config.BasePrices = {
    ['A_C_Cow'] = 50,
    ['A_C_Bull_01'] = 75,
    ['A_C_Ox_01'] = 60
}

Config.PriceVariation = 0.15 -- 15% price variation
Config.PriceUpdateInterval = 300000 -- Update prices every 5 minutes

-- AI Cowboys Settings
Config.EnableAICowboys = true
Config.CowboySpawnChance = 0.1 -- 10% chance
Config.CowboyModels = {
    'U_M_M_BHT_ODRISCOLLSLEEPING',
    'U_M_M_BHT_BANDITOSHOOTOUT',
    'CS_CRACKPOTROBOT'
}

-- Rustlers Settings
Config.EnableRustlers = true
Config.RustlerSpawnChance = 0.05 -- 5% chance
Config.RustlerModels = {
    'G_M_M_UNIRANCHERS_01',
    'G_M_M_UNIMOUNTAINMEN_01'
}
Config.RustlerReward = 25 -- XP for defeating rustlers

-- Experience System
Config.XPLevels = {
    [1] = 0,
    [2] = 100,
    [3] = 250,
    [4] = 500,
    [5] = 1000,
    [6] = 2000,
    [7] = 3500,
    [8] = 5500,
    [9] = 8000,
    [10] = 12000
}

Config.LevelBonuses = {
    [2] = {type = "price", value = 1.05}, -- 5% better prices
    [3] = {type = "price", value = 1.10},
    [5] = {type = "herd_size", value = 15},
    [7] = {type = "price", value = 1.15},
    [10] = {type = "herd_size", value = 20}
}

-- Controller Settings
Config.ControllerSupport = true
Config.HerdingButton = 0x8FD015D8 -- Right Bumper (RB/R1)
Config.MenuButton = 0xC7B5340A -- Left Bumper (LB/L1)

-- Prompt Settings
Config.PromptGroup = GetRandomIntInRange(0, 0xffffff)
