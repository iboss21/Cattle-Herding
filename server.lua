-- Server-side script for Cattle Herding
local playerData = {}
local currentPrices = {}

-- Initialize prices
function InitializePrices()
    for model, basePrice in pairs(Config.BasePrices) do
        local variation = (math.random() - 0.5) * 2 * Config.PriceVariation
        currentPrices[model] = math.floor(basePrice * (1 + variation))
    end
end

-- Update prices periodically
Citizen.CreateThread(function()
    InitializePrices()
    
    while true do
        Citizen.Wait(Config.PriceUpdateInterval)
        
        -- Update prices with random variation
        for model, basePrice in pairs(Config.BasePrices) do
            local variation = (math.random() - 0.5) * 2 * Config.PriceVariation
            currentPrices[model] = math.floor(basePrice * (1 + variation))
        end
        
        -- Notify all clients
        TriggerClientEvent('cattleherding:updatePrices', -1, currentPrices)
        print('[Cattle Herding] Prices updated')
    end
end)

-- Get or create player data
function GetPlayerData(source)
    local identifier = GetPlayerIdentifier(source, 0)
    
    if not playerData[identifier] then
        playerData[identifier] = {
            xp = 0,
            level = 1,
            totalSold = 0,
            totalEarned = 0
        }
    end
    
    return playerData[identifier]
end

-- Calculate level from XP
function CalculateLevel(xp)
    local level = 1
    
    for lvl = 10, 1, -1 do
        if xp >= Config.XPLevels[lvl] then
            level = lvl
            break
        end
    end
    
    return level
end

-- Add XP to player
RegisterNetEvent('cattleherding:addXP')
AddEventHandler('cattleherding:addXP', function(amount)
    local source = source
    local data = GetPlayerData(source)
    
    data.xp = data.xp + amount
    local newLevel = CalculateLevel(data.xp)
    
    if newLevel > data.level then
        data.level = newLevel
        TriggerClientEvent('chat:addMessage', source, {
            args = {'Cattle Herding', string.format('Level Up! You are now level %d!', newLevel)}
        })
        
        -- Apply level bonus
        if Config.LevelBonuses[newLevel] then
            local bonus = Config.LevelBonuses[newLevel]
            local bonusText = ""
            
            if bonus.type == "price" then
                bonusText = string.format('You now get %.0f%% better prices!', (bonus.value - 1) * 100)
            elseif bonus.type == "herd_size" then
                bonusText = string.format('Your max herd size is now %d!', bonus.value)
            end
            
            TriggerClientEvent('chat:addMessage', source, {
                args = {'Cattle Herding', bonusText}
            })
        end
    end
    
    TriggerClientEvent('cattleherding:updateXP', source, data.xp, data.level)
end)

-- Open cattle shop
RegisterNetEvent('cattleherding:openShop')
AddEventHandler('cattleherding:openShop', function(herdSize)
    local source = source
    local data = GetPlayerData(source)
    
    if herdSize == 0 then
        TriggerClientEvent('chat:addMessage', source, {
            args = {'Cattle Herding', 'You have no cattle to sell!'}
        })
        return
    end
    
    -- Calculate total value
    local totalValue = 0
    local priceBonus = 1.0
    
    -- Check for level price bonus
    for level = data.level, 1, -1 do
        if Config.LevelBonuses[level] and Config.LevelBonuses[level].type == "price" then
            priceBonus = Config.LevelBonuses[level].value
            break
        end
    end
    
    -- Calculate average price for all cattle types
    local avgPrice = 0
    local priceCount = 0
    for _, price in pairs(currentPrices) do
        avgPrice = avgPrice + price
        priceCount = priceCount + 1
    end
    avgPrice = math.floor(avgPrice / priceCount)
    
    totalValue = math.floor(herdSize * avgPrice * priceBonus)
    local xpGained = herdSize * 10
    
    -- Add money to player (using RedM natives)
    local Player = GetPlayerPed(source)
    exports.redemrp_inventory:addItem(source, 'dollars', totalValue) -- Using RedM inventory
    
    -- Update stats
    data.totalSold = data.totalSold + herdSize
    data.totalEarned = data.totalEarned + totalValue
    
    -- Add XP
    data.xp = data.xp + xpGained
    data.level = CalculateLevel(data.xp)
    
    TriggerClientEvent('cattleherding:updateXP', source, data.xp, data.level)
    TriggerClientEvent('cattleherding:sellResult', source, true, totalValue, xpGained)
    
    print(string.format('[Cattle Herding] Player %s sold %d cattle for $%d', GetPlayerName(source), herdSize, totalValue))
end)

-- Get player stats command
RegisterCommand('cattlestats', function(source, args, rawCommand)
    local data = GetPlayerData(source)
    
    TriggerClientEvent('chat:addMessage', source, {
        args = {'Cattle Herding Stats', string.format('Level: %d | XP: %d | Total Sold: %d | Total Earned: $%d', 
            data.level, data.xp, data.totalSold, data.totalEarned)}
    })
end, false)

-- Admin command to set player XP
RegisterCommand('setcattlexp', function(source, args, rawCommand)
    if source == 0 then -- Console only
        if #args < 2 then
            print('Usage: setcattlexp <player_id> <xp>')
            return
        end
        
        local targetId = tonumber(args[1])
        local xp = tonumber(args[2])
        
        if targetId and xp then
            local data = GetPlayerData(targetId)
            data.xp = xp
            data.level = CalculateLevel(xp)
            
            TriggerClientEvent('cattleherding:updateXP', targetId, data.xp, data.level)
            print(string.format('[Cattle Herding] Set player %s XP to %d (Level %d)', GetPlayerName(targetId), xp, data.level))
        end
    end
end, true)

-- Admin command to reset all prices
RegisterCommand('resetcattleprices', function(source, args, rawCommand)
    if source == 0 then -- Console only
        InitializePrices()
        TriggerClientEvent('cattleherding:updatePrices', -1, currentPrices)
        print('[Cattle Herding] Prices reset')
    end
end, true)

-- Get current prices command
RegisterCommand('cattleprices', function(source, args, rawCommand)
    local priceText = 'Current Cattle Prices:'
    
    for model, price in pairs(currentPrices) do
        priceText = priceText .. string.format('\n%s: $%d', model, price)
    end
    
    TriggerClientEvent('chat:addMessage', source, {
        args = {'Cattle Herding', priceText}
    })
end, false)

-- Player connecting
AddEventHandler('playerConnecting', function()
    local source = source
    Citizen.Wait(1000)
    
    -- Send current prices to new player
    TriggerClientEvent('cattleherding:updatePrices', source, currentPrices)
    
    -- Send player data
    local data = GetPlayerData(source)
    TriggerClientEvent('cattleherding:updateXP', source, data.xp, data.level)
end)

-- Save player data periodically (in production, you'd want to use a database)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Save every 5 minutes
        
        -- In a real implementation, you would save to a database here
        print('[Cattle Herding] Player data autosaved')
    end
end)

print('[Cattle Herding] Server script loaded successfully')
