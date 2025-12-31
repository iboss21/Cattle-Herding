--[[
    Dynamic Pricing System for tlw_cattle_herding
    Handles market fluctuations and price calculations
]]

Pricing = {}

-- Current market prices (cached in memory)
local marketPrices = {}
local lastPriceUpdate = 0

-- Initialize pricing system
function Pricing.Init()
    -- Load initial prices from database
    DB.GetAllMarkets(function(markets)
        for _, market in ipairs(markets) do
            marketPrices[market.location_id] = {
                demand = market.demand,
                price_multiplier = market.price_multiplier,
                last_sale = market.last_sale_time,
                total_sales = market.total_sales
            }
        end
        
        Utils.Debug('Loaded prices for ' .. #markets .. ' markets')
    end)
    
    -- Start price update thread
    Pricing.StartPriceUpdateThread()
end

-- Start automatic price updates
function Pricing.StartPriceUpdateThread()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(60000) -- Check every minute
            
            local currentHour = Utils.GetGameHour()
            local targetHour = Config.Pricing.changes_at_hour or 6
            
            -- Update prices at configured hour
            if currentHour == targetHour and os.time() - lastPriceUpdate > 3600 then
                Pricing.UpdateAllPrices()
                lastPriceUpdate = os.time()
            end
        end
    end)
end

-- Update all market prices
function Pricing.UpdateAllPrices()
    Utils.Debug('Updating all market prices...')
    
    for locationId, data in pairs(marketPrices) do
        -- Generate new demand (random walk)
        local variance = Config.Pricing.variance or {min = 0.80, max = 1.20}
        local newDemand = variance.min + math.random() * (variance.max - variance.min)
        
        -- Apply demand smoothing (don't change too drastically)
        newDemand = Utils.Lerp(data.demand, newDemand, 0.3)
        newDemand = Utils.Clamp(newDemand, variance.min, variance.max)
        
        -- Update in memory and database
        marketPrices[locationId].demand = newDemand
        DB.UpdateMarketDemand(locationId, newDemand)
    end
    
    -- Notify all clients
    TriggerClientEvent('tlw_cattle:pricesUpdated', -1, marketPrices)
    
    Utils.Debug('Market prices updated')
end

-- Get current prices for all markets
function Pricing.GetAllPrices()
    local prices = {}
    
    for locationId, data in pairs(marketPrices) do
        prices[locationId] = {
            demand = data.demand,
            multiplier = data.price_multiplier
        }
    end
    
    return prices
end

-- Calculate sell price for cattle
function Pricing.CalculateSellPrice(cattleType, location, playerLevel, cattleCount, distance, survivalRate, timeTaken, isNight)
    -- Get base price
    local cattleInfo = Utils.GetCattleTypeByModel(cattleType)
    if not cattleInfo then
        Utils.Debug('Unknown cattle type:', cattleType)
        return 0
    end
    
    local basePrice = cattleInfo.sell_base or cattleInfo.base_price or 50
    
    -- Get location multiplier
    local locationMultiplier = 1.0
    if marketPrices[location] then
        locationMultiplier = marketPrices[location].price_multiplier * marketPrices[location].demand
    end
    
    -- Distance bonus
    local distanceBonus = 0
    if Config.Pricing.distance_bonus_enabled then
        local distanceKm = Utils.MetersToKm(distance or 0)
        distanceBonus = math.min(
            distanceKm * Config.Pricing.distance_bonus_per_km,
            Config.Pricing.max_distance_bonus
        )
    end
    
    -- Time of day multiplier
    local timeMultiplier = 1.0
    if isNight and Config.Pricing.night_premium then
        timeMultiplier = Config.Pricing.night_premium
    end
    
    -- Survival bonus
    local survivalBonus = 1.0
    if survivalRate >= (Config.Pricing.bonus_survival_threshold or 0.9) then
        survivalBonus = Config.Pricing.bonus_survival_multiplier or 1.1
    end
    
    -- Fast delivery bonus
    local speedBonus = 1.0
    if timeTaken and timeTaken <= (Config.Pricing.fast_delivery_threshold or 600) then
        speedBonus = Config.Pricing.fast_delivery_bonus or 1.08
    end
    
    -- XP level bonus
    local xpBonus = 0
    if playerLevel and Config.XP then
        xpBonus = math.min(
            playerLevel * (Config.XP.price_boost_per_level or 0.01),
            Config.XP.max_price_boost or 0.25
        )
    end
    
    -- Calculate final price per cattle
    local pricePerCattle = basePrice * locationMultiplier * (1 + distanceBonus) * timeMultiplier * survivalBonus * speedBonus * (1 + xpBonus)
    
    -- Total payout
    local totalPayout = math.floor(pricePerCattle * cattleCount)
    
    -- Perfect delivery bonus (flat amount)
    if survivalRate >= 1.0 and Config.Pricing.bonus_no_losses then
        totalPayout = totalPayout + Config.Pricing.bonus_no_losses
    end
    
    Utils.Debug(string.format('Price calc: base=%d, location=%.2f, dist=%.2f, time=%.2f, survival=%.2f, speed=%.2f, xp=%.2f, total=%d',
        basePrice, locationMultiplier, 1 + distanceBonus, timeMultiplier, survivalBonus, speedBonus, 1 + xpBonus, totalPayout))
    
    return totalPayout, {
        base = basePrice,
        location_mult = locationMultiplier,
        distance_bonus = distanceBonus,
        time_mult = timeMultiplier,
        survival_bonus = survivalBonus,
        speed_bonus = speedBonus,
        xp_bonus = xpBonus,
        price_per_cattle = pricePerCattle
    }
end

-- Record a sale (affects demand)
function Pricing.RecordSale(location, cattleCount)
    if marketPrices[location] then
        -- Increase total sales
        marketPrices[location].total_sales = (marketPrices[location].total_sales or 0) + 1
        marketPrices[location].last_sale = os.time()
        
        -- Slightly reduce demand when cattle are sold
        if Config.Pricing.delivery_demand_impact then
            local demandReduction = Config.Pricing.delivery_demand_impact * cattleCount
            marketPrices[location].demand = math.max(
                Config.Pricing.demand_min or 0.7,
                marketPrices[location].demand - demandReduction
            )
        end
        
        -- Update database
        DB.RecordMarketSale(location)
        DB.UpdateMarketDemand(location, marketPrices[location].demand)
    end
end

-- Get buy price for cattle (at ranch)
function Pricing.GetBuyPrice(cattleType, count)
    local cattleInfo = Utils.GetCattleTypeByModel(cattleType)
    if not cattleInfo then return 0 end
    
    local pricePerCattle = cattleInfo.buy_price or 50
    return pricePerCattle * count
end

-- Admin: Set market demand manually
function Pricing.SetMarketDemand(location, demand)
    if marketPrices[location] then
        marketPrices[location].demand = Utils.Clamp(demand, 0.1, 2.0)
        DB.UpdateMarketDemand(location, marketPrices[location].demand)
        
        -- Notify clients
        TriggerClientEvent('tlw_cattle:pricesUpdated', -1, marketPrices)
        return true
    end
    return false
end

-- Get market info for client UI
function Pricing.GetMarketInfo()
    local info = {}
    
    for locationId, data in pairs(marketPrices) do
        -- Find location config
        local locationName = locationId
        for _, loc in ipairs(Config.SellLocations or {}) do
            if loc.id == locationId then
                locationName = loc.name
                break
            end
        end
        
        -- Calculate example prices for each cattle type
        local prices = {}
        for _, cattleInfo in ipairs(Config.Cattle.types or {}) do
            local basePrice = cattleInfo.sell_base or cattleInfo.base_price or 50
            local currentPrice = math.floor(basePrice * data.price_multiplier * data.demand)
            prices[cattleInfo.id or cattleInfo.model] = {
                name = cattleInfo.name,
                price = currentPrice
            }
        end
        
        info[locationId] = {
            name = locationName,
            demand = Utils.Round(data.demand, 2),
            multiplier = data.price_multiplier,
            prices = prices,
            last_sale = data.last_sale,
            total_sales = data.total_sales
        }
    end
    
    return info
end

-- Force price update (admin command)
function Pricing.ForceUpdate()
    Pricing.UpdateAllPrices()
    return true
end

Utils.Debug('Pricing module loaded')

return Pricing
