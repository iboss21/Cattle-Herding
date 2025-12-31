--[[
    tlw_cattle_herding - Authentic Cattle Herding for RedM
    
    Philosophy: Real cattle behavior, not game mechanics
    Focus: Pressure, patience, positioning - not buttons and menus
]]

Config = {}

-- ==============================================
-- CORE SETTINGS
-- ==============================================
Config.Framework = 'RSG'
Config.Debug = false

-- ==============================================
-- BUY & SELL LOCATIONS (Simple & Clear)
-- ==============================================

-- Where you BUY cattle
Config.BuyRanches = {
    {
        name = "Emerald Ranch",
        prompt_coords = vector3(1424.07, 365.84, 89.88),
        spawn_points = {
            vector3(1428.34, 368.92, 89.91),
            vector3(1428.34, 372.25, 89.91),
            vector3(1431.67, 368.92, 89.91),
            vector3(1431.67, 372.25, 89.91),
            vector3(1435.00, 368.92, 89.91),
        }
    },
    {
        name = "McFarlane's Ranch",
        prompt_coords = vector3(-2237.89, -2393.12, 63.21),
        spawn_points = {
            vector3(-2241.22, -2396.45, 63.23),
            vector3(-2244.55, -2396.45, 63.23),
            vector3(-2247.88, -2396.45, 63.23),
            vector3(-2241.22, -2399.78, 63.23),
            vector3(-2244.55, -2399.78, 63.23),
        }
    }
}

-- Where you SELL cattle
Config.SellYards = {
    {
        name = "Valentine Auction Yard",
        coords = vector3(-181.01, 627.24, 114.09),
        radius = 30.0,
        price_multiplier = 1.0
    },
    {
        name = "Blackwater",
        coords = vector3(-813.42, -1324.19, 43.63),
        radius = 30.0,
        price_multiplier = 1.05
    },
    {
        name = "Saint Denis",
        coords = vector3(2716.38, -1190.11, 47.39),
        radius = 30.0,
        price_multiplier = 1.2  -- Best price, longest drive
    }
}

-- ==============================================
-- CATTLE PROPERTIES
-- ==============================================
Config.Cattle = {
    -- Available types
    types = {
        {model = 'A_C_Cow', name = 'Cow', buy_price = 45, sell_base = 60},
        {model = 'A_C_Bull_01', name = 'Bull', buy_price = 70, sell_base = 90},
        {model = 'A_C_Ox_01', name = 'Ox', buy_price = 55, sell_base = 75},
    },
    
    -- How many you can buy at once
    min_purchase = 1,
    max_purchase = 25,
    
    -- One active herd at a time
    max_active_herds = 1,
}

-- ==============================================
-- HERD AI - THE MAGIC
-- ==============================================
Config.HerdAI = {
    -- Core behavior radii
    cohesion_radius = 12.0,           -- Cattle try to stay within this radius
    separation_min = 2.5,             -- Minimum space between cattle
    player_pressure_radius = 18.0,    -- How far player influence reaches
    
    -- Sweet spot for herding
    optimal_herd_distance = 10.0,     -- Perfect distance behind herd
    too_close_distance = 4.0,         -- Causes bunching/stress
    too_far_distance = 25.0,          -- Cattle slow down/stop
    
    -- Natural movement
    wander_when_idle = true,
    graze_probability = 0.75,         -- 75% chance to graze when stopped
    graze_duration = {min = 8, max = 20}, -- Seconds
    head_down_while_grazing = true,
    
    -- Leader dynamics
    natural_leader = true,            -- One cattle naturally leads
    leader_ahead_distance = 4.0,
    others_follow_leader = true,
    follow_spacing = 3.0,
    
    -- Speed states (meters/second)
    speed = {
        graze = 0.0,
        idle_walk = 0.5,
        walk = 1.2,
        trot = 2.5,
        run = 4.0,
        panic = 6.0,
    },
    
    -- Panic system
    panic = {
        duration = {min = 12, max = 25},
        spread_radius = 18.0,
        spread_chance = 0.4,
        triggers = {
            gunshot_nearby = 25.0,        -- Radius
            explosion = 40.0,
            player_sprinting_close = 5.0,
            predator = 15.0,
            rustler_shooting = 30.0,
        },
        calming_time = 5.0,               -- Seconds standing still to calm
    },
    
    -- Stragglers
    straggler_threshold = 35.0,       -- Distance from herd center
    straggler_warning_at = 25.0,
    straggler_lost_after = 120,       -- Seconds
    straggler_tries_to_return = true,
    return_speed_multiplier = 1.4,
    
    -- Terrain awareness
    avoid_water_depth = 1.5,          -- Meters
    avoid_cliff_edge = 5.0,
    slope_slowdown_angle = 25.0,      -- Degrees
    
    -- AI tick rates (milliseconds)
    update_rate = 400,                -- Main AI loop
    cohesion_check = 800,             -- Group behavior
    panic_check = 1500,               -- Panic spread
}

-- ==============================================
-- PLAYER INFLUENCE SYSTEM
-- ==============================================
Config.PlayerControl = {
    -- Speed control (Arrow Keys)
    speed_keys = {
        increase = 0x6319DB71,        -- Up Arrow
        decrease = 0x05CA7C52,        -- Down Arrow
    },
    speed_adjustment = 0.4,           -- How much each press changes
    speed_range = {min = 0.8, max = 2.5},
    
    -- Direction bias (subtle steering)
    direction_keys = {
        left = 0xA65EBAB4,            -- Left Arrow
        right = 0xDEB34313,           -- Right Arrow
    },
    bias_strength = 0.25,             -- Not instant turning, gradual
    bias_decay_time = 4.0,            -- Seconds until bias fades
    
    -- Positioning matters more than buttons
    behind_herd_bonus = 1.2,          -- Cattle move better when you're behind
    beside_herd_effect = 0.7,         -- Cattle turn away from you
    ahead_of_herd_penalty = 0.4,      -- Cattle slow/stop if you're ahead
    
    -- Horse matters
    horse_speed_affects_herd = true,
    galloping_causes_panic = true,    -- Within 8m
}

-- ==============================================
-- DYNAMIC PRICING
-- ==============================================
Config.Pricing = {
    -- Daily market fluctuation
    changes_at_hour = 6,              -- 6am game time
    variance = {min = 0.80, max = 1.20}, -- ±20% daily
    
    -- Bonuses
    distance_bonus = 0.012,           -- 1.2% per kilometer
    max_distance_bonus = 0.35,        -- Cap at 35%
    night_premium = 1.12,             -- 12% more 8pm-6am
    
    -- Survival bonus
    perfect_delivery = 150,           -- All cattle alive
    good_delivery_threshold = 0.85,   -- 85% alive
    good_delivery_bonus = 1.1,        -- 10% more
    
    -- Time pressure (optional)
    fast_delivery_threshold = 600,    -- 10 minutes
    fast_delivery_bonus = 1.08,       -- 8% more
}

-- ==============================================
-- XP SYSTEM (Unlocks Better Herding)
-- ==============================================
Config.XP = {
    -- What gives XP
    per_km_driven = 3,
    per_cattle_sold = 12,
    perfect_delivery = 120,
    rustler_defeated = 30,
    
    -- Levels
    levels = {
        1, 100, 250, 500, 1000, 2000, 3500, 5500, 8500, 12500,
        17000, 22000, 28000, 35000, 43000, 52000, 62000, 73000, 85000, 100000
    },
    
    -- What levels unlock
    benefits = {
        [1] = "Start herding",
        [3] = "Cattle panic 15% less",
        [5] = "+5% sell prices",
        [7] = "Cattle follow better",
        [10] = "+10% sell prices, Max herd +5",
        [12] = "Cattle panic 30% less",
        [15] = "+15% sell prices",
        [18] = "Cattle rarely panic",
        [20] = "Master Rancher: +20% prices, Max herd +10"
    },
    
    -- Actual stat changes per level
    panic_reduction_per_level = 0.02,     -- 2% less panic per level
    price_boost_per_level = 0.01,         -- 1% better prices per level
    max_price_boost = 0.25,               -- Cap at 25%
    cohesion_bonus_per_level = 0.01,      -- Cattle stick together better
}

-- ==============================================
-- AI COWBOYS (Hired Help)
-- ==============================================
Config.AICowboys = {
    enabled = true,
    unlock_at_level = 8,
    max_count = 2,
    cost_each = 75,
    
    -- What they do
    push_stragglers = true,
    flank_herd = true,
    warn_rustlers = true,
    shoot_back = true,
    
    -- Positioning (relative to herd)
    rear_guard_offset = -12.0,
    side_flank_offset = 8.0,
    
    -- Not perfect - they're helpers not robots
    effectiveness = 0.7,              -- 70% as good as player
    reaction_time = 2.5,              -- Seconds delay
}

-- ==============================================
-- RUSTLERS (The Danger)
-- ==============================================
Config.Rustlers = {
    enabled = true,
    
    -- When they appear
    base_chance = 0.04,               -- 4% per check
    check_every_seconds = 150,
    
    -- More likely if...
    night_multiplier = 2.2,           -- Much more dangerous at night
    remote_area_multiplier = 1.5,     -- Far from towns
    large_herd_multiplier = 1.3,      -- Bigger target
    
    -- Spawn
    count = {min = 2, max = 5},
    distance = {min = 60, max = 120},
    
    -- What they do
    scare_cattle = true,
    shoot_at_player = true,
    can_steal_cattle = true,
    steal_chance_per_attempt = 0.25,  -- 25% per rustle
    attempts_before_fleeing = 3,
    
    -- Rewards for defending
    xp_per_kill = 30,
    money_per_kill = 8,
    bonus_all_killed = 100,           -- XP
}

-- ==============================================
-- HUD (Minimal & Clean)
-- ==============================================
Config.HUD = {
    enabled = true,
    position = {x = 0.015, y = 0.88}, -- Bottom left
    
    -- What shows
    show_count = true,                -- "Herd: 8/10"
    show_state = true,                -- "Calm" / "Moving" / "Panicking!"
    show_stragglers = true,           -- "2 Stragglers"
    show_destination = true,          -- "Valentine - 2.1km"
    show_level = true,                -- "Level 7"
    
    -- Colors
    text_normal = {255, 255, 255, 230},
    text_warning = {255, 200, 50, 255},
    text_danger = {255, 60, 60, 255},
    
    -- Toggle key
    toggle_key = 0xCEE12B50,          -- F7
    
    update_every_ms = 1000,
}

-- ==============================================
-- INTERACTION PROMPTS
-- ==============================================
Config.Prompts = {
    buy_cattle = {
        key = 0xE8342FF2,             -- E / Cross
        hold_time = 1200,             -- Milliseconds
        text = "Buy Cattle"
    },
    
    sell_cattle = {
        key = 0xE8342FF2,
        hold_time = 1500,
        text = "Sell Herd"
    },
    
    -- Simple purchase dialog (no heavy UI)
    quick_buy_amounts = {3, 5, 10, 15, 20},
}

-- ==============================================
-- BLIPS (Map Markers)
-- ==============================================
Config.Blips = {
    buy_locations = {
        sprite = 'blip_ambient_herd',
        color = 'WHITE',
        label = "Buy Cattle"
    },
    
    sell_locations = {
        sprite = 'blip_shop_butcher', 
        color = 'YELLOW_ORANGE',
        label = "Sell Cattle"
    },
    
    active_herd = {
        enabled = true,
        sprite = 'blip_proc_home',
        color = 'WHITE',
        label = "Your Herd",
        updates_with_herd = true,     -- Blip follows herd center
    }
}

-- ==============================================
-- ANTI-EXPLOIT
-- ==============================================
Config.Security = {
    -- Server validates everything
    server_validates_sale = true,
    server_validates_distance = true,
    server_calculates_payout = true,
    
    -- Sanity checks
    max_speed_tolerance = 25.0,       -- m/s
    min_sale_time = 90,               -- Seconds (prevent instant TP sells)
    sale_radius_tolerance = 5.0,      -- Extra meters allowed
    
    -- Rate limits
    cooldown_buy = 3000,              -- ms
    cooldown_sell = 2000,
}

-- ==============================================
-- MESSAGES
-- ==============================================
Config.Messages = {
    buy_success = "Bought %d %s for $%d",
    buy_fail_money = "Not enough money",
    buy_fail_active = "You already have cattle",
    
    sell_success = "Sold %d cattle for $%d (+%d XP)",
    sell_partial = "Sold %d of %d cattle for $%d (+%d XP)",
    sell_none = "No cattle nearby to sell",
    
    straggler = "⚠ %d cattle straying!",
    lost = "Lost %d cattle",
    panic = "⚠ Herd panicking!",
    calm = "Herd calmed down",
    
    rustlers = "⚠ RUSTLERS ATTACKING!",
    rustler_defeated = "Rustlers defeated (+%d XP)",
    cattle_stolen = "%d cattle stolen!",
    
    level_up = "🌟 Level %d! %s",
    
    cowboy_hired = "Hired %d cowboys ($%d)",
    cowboy_locked = "Unlock at level %d",
}

-- ==============================================
-- PERFORMANCE
-- ==============================================
Config.Performance = {
    -- Cattle stop ticking if too far from any player
    max_active_distance = 200.0,
    
    -- Server limits
    max_herds_on_server = 15,
    
    -- Client optimization
    lod_distance = 150.0,             -- Simplified AI beyond this
}

-- ==============================================
-- DEBUG MODE
-- ==============================================
Config.DebugVisualization = {
    draw_herd_center = true,
    draw_cohesion_circle = true,
    draw_pressure_zones = true,
    draw_cattle_states = true,
    draw_straggler_lines = true,
    draw_ai_paths = false,            -- Expensive
}

print('^2[Cattle Herding]^7 Authentic cattle behavior loaded')
