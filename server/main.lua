--[[
    Server Main Logic for tlw_cattle_herding
    The Land of Wolves - www.wolves.land
    Developer: iBoss
    
    Handles contracts, buying, selling, XP, and all server-authoritative operations
]]

-- Framework Detection (LXRCore primary, RSG-Core supported)
local CoreObject = nil
local CoreName = nil

if Config.Framework == 'LXRCore' then
    if GetResourceState('lxr-core') == 'started' then
        CoreObject = exports['lxr-core']:GetCoreObject()
        CoreName = 'LXRCore'
    else
        print('^1[TLW Cattle Herding]^7 ERROR: LXRCore specified in config but not found!')
    end
elseif Config.Framework == 'RSG' then
    if GetResourceState('rsg-core') == 'started' then
        CoreObject = exports['rsg-core']:GetCoreObject()
        CoreName = 'RSG-Core'
    else
        print('^1[TLW Cattle Herding]^7 ERROR: RSG-Core specified in config but not found!')
    end
else
    -- Auto-detect
    if GetResourceState('lxr-core') == 'started' then
        CoreObject = exports['lxr-core']:GetCoreObject()
        CoreName = 'LXRCore'
    elseif GetResourceState('rsg-core') == 'started' then
        CoreObject = exports['rsg-core']:GetCoreObject()
        CoreName = 'RSG-Core'
    end
end

if CoreObject then
    print(string.format('^2[TLW Cattle Herding]^7 Server using framework: ^3%s^7', CoreName))
else
    print('^1[TLW Cattle Herding]^7 CRITICAL ERROR: No supported framework found! Resource will not function.')
    print('^1[TLW Cattle Herding]^7 Please install LXRCore or RSG-Core framework.')
end

-- Active contracts (citizenid => contract data)
local activeContracts = {}

-- Player data cache
local playerDataCache = {}

-- Rate limiting
local rateLimits = {}

-- ==========================================
-- INITIALIZATION
-- ==========================================

Citizen.CreateThread(function()
    Utils.Debug('Server initializing...')
    
    -- Initialize database
    DB.Init()
    
    -- Initialize pricing system
    Pricing.Init()
    
    -- Clean up old contracts (30+ days old)
    DB.CleanOldContracts(30, function(count)
        if count > 0 then
            print(string.format('^3[Cattle]^7 Cleaned up %d old contracts', count))
        end
    end)
    
    print('^2[TLW Cattle Herding]^7 Server started successfully | www.wolves.land')
end)

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

-- Safe wrapper for getting player (handles missing framework)
local function GetPlayer(source)
    if not CoreObject then
        print('^1[TLW Cattle Herding]^7 ERROR: Cannot get player - no framework loaded')
        return nil
    end
    return CoreObject.Functions.GetPlayer(source)
end

-- Get or load player data
local function GetPlayerData(source)
    local Player = GetPlayer(source)
    if not Player then return nil end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Return cached if available
    if playerDataCache[citizenid] then
        return playerDataCache[citizenid]
    end
    
    return nil
end

-- Load player data from database
local function LoadPlayerData(source, callback)
    local Player = GetPlayer(source)
    if not Player then
        callback(nil)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    DB.GetPlayerData(citizenid, function(data)
        if data then
            playerDataCache[citizenid] = data
            callback(data)
        else
            callback(nil)
        end
    end)
end

-- Check rate limit
local function CheckRateLimit(source, action, cooldown)
    local identifier = source .. '_' .. action
    local now = os.time()
    
    if rateLimits[identifier] and (now - rateLimits[identifier]) < (cooldown / 1000) then
        return false
    end
    
    rateLimits[identifier] = now
    return true
end

-- Validate player can perform action
local function ValidatePlayer(source)
    local Player = GetPlayer(source)
    if not Player then return false end
    
    -- Job whitelist check if configured
    if Config.Integration and Config.Integration.job_whitelist then
        local playerJob = Player.PlayerData.job.name
        if not Utils.TableContains(Config.Integration.job_whitelist, playerJob) then
            return false
        end
    end
    
    return true
end

-- ==========================================
-- PLAYER CONNECTION & DATA
-- ==========================================

-- Player connecting
AddEventHandler('playerConnecting', function()
    local source = source
    
    Citizen.SetTimeout(2000, function()
        LoadPlayerData(source, function(data)
            if data then
                -- Send initial data to client
                TriggerClientEvent('tlw_cattle:playerDataLoaded', source, data)
                
                -- Send current prices
                TriggerClientEvent('tlw_cattle:pricesUpdated', source, Pricing.GetAllPrices())
            end
        end)
    end)
end)

-- Player dropped
AddEventHandler('playerDropped', function()
    local source = source
    local Player = GetPlayer(source)
    
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        -- Check if player has active contract
        if activeContracts[citizenid] then
            -- Mark contract as abandoned (they can resume later if we want)
            Utils.Debug('Player dropped with active contract:', citizenid)
            -- Could save state here
        end
        
        -- Clear cache
        playerDataCache[citizenid] = nil
        activeContracts[citizenid] = nil
    end
end)

-- ==========================================
-- BUY CATTLE
-- ==========================================

RegisterNetEvent('tlw_cattle:buyCattle', function(cattleType, count, locationId)
    local source = source
    
    -- Rate limit
    if not CheckRateLimit(source, 'buy', Config.Security.cooldown_buy or 3000) then
        TriggerClientEvent('tlw_cattle:buyFailed', source, 'Too fast! Wait a moment.')
        return
    end
    
    -- Validate
    if not ValidatePlayer(source) then
        TriggerClientEvent('tlw_cattle:buyFailed', source, 'Not authorized')
        return
    end
    
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check for active contract
    if activeContracts[citizenid] then
        TriggerClientEvent('tlw_cattle:buyFailed', source, Config.Messages.buy_fail_active)
        return
    end
    
    -- Validate cattle type
    local cattleInfo = Utils.GetCattleTypeByModel(cattleType)
    if not cattleInfo then
        Utils.Debug('Invalid cattle type:', cattleType)
        return
    end
    
    -- Validate count
    count = tonumber(count)
    if not count or count < Config.Cattle.min_purchase or count > Config.Cattle.max_purchase then
        TriggerClientEvent('tlw_cattle:buyFailed', source, 'Invalid amount')
        return
    end
    
    -- Calculate cost
    local totalCost = Pricing.GetBuyPrice(cattleType, count)
    
    -- Check money
    local money = Player.Functions.GetMoney('cash')
    if money < totalCost then
        TriggerClientEvent('tlw_cattle:buyFailed', source, Config.Messages.buy_fail_money)
        return
    end
    
    -- Remove money
    Player.Functions.RemoveMoney('cash', totalCost, 'cattle-purchase')
    
    -- Generate contract token
    local contractToken = Utils.GenerateToken()
    
    -- Create contract in database
    DB.CreateContract({
        citizenid = citizenid,
        contract_token = contractToken,
        cattle_type = cattleType,
        herd_size = count,
        buy_location = locationId,
        buy_price_total = totalCost,
        cowboys_hired = 0,
        cowboy_cost = 0
    }, function(contractId)
        if contractId then
            -- Store in active contracts
            activeContracts[citizenid] = {
                id = contractId,
                token = contractToken,
                cattle_type = cattleType,
                herd_size = count,
                cattle_alive = count,
                buy_location = locationId,
                start_time = os.time(),
                distance_traveled = 0
            }
            
            -- Notify client to spawn cattle
            TriggerClientEvent('tlw_cattle:purchaseSuccess', source, {
                token = contractToken,
                cattle_type = cattleType,
                count = count,
                location = locationId,
                cost = totalCost
            })
            
            Utils.Debug(string.format('Player %s bought %d %s for $%d', citizenid, count, cattleType, totalCost))
        else
            -- Refund on error
            Player.Functions.AddMoney('cash', totalCost, 'cattle-purchase-refund')
            TriggerClientEvent('tlw_cattle:buyFailed', source, 'Database error')
        end
    end)
end)

-- ==========================================
-- HIRE AI COWBOYS
-- ==========================================

RegisterNetEvent('tlw_cattle:hireCowboys', function(count)
    local source = source
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check for active contract
    if not activeContracts[citizenid] then
        return
    end
    
    -- Check level requirement
    LoadPlayerData(source, function(playerData)
        if not playerData then return end
        
        local requiredLevel = Config.AICowboys.unlock_at_level or 8
        if playerData.level < requiredLevel then
            TriggerClientEvent('tlw_cattle:cowboyHireFailed', source, string.format(Config.Messages.cowboy_locked, requiredLevel))
            return
        end
        
        -- Check max count
        count = tonumber(count)
        if not count or count < 1 or count > (Config.AICowboys.max_count or 2) then
            return
        end
        
        -- Calculate cost
        local costPerCowboy = Config.AICowboys.cost_each or 75
        local totalCost = costPerCowboy * count
        
        -- Check money
        local money = Player.Functions.GetMoney('cash')
        if money < totalCost then
            TriggerClientEvent('tlw_cattle:cowboyHireFailed', source, Config.Messages.buy_fail_money)
            return
        end
        
        -- Remove money
        Player.Functions.RemoveMoney('cash', totalCost, 'cattle-cowboys')
        
        -- Update contract
        local contract = activeContracts[citizenid]
        contract.cowboys_hired = count
        contract.cowboy_cost = totalCost
        
        DB.UpdateContractProgress(contract.token, {
            cowboys_hired = count,
            cowboy_cost = totalCost
        })
        
        -- Notify client
        TriggerClientEvent('tlw_cattle:cowboysHired', source, count, totalCost)
        
        Utils.Debug(string.format('Player %s hired %d cowboys for $%d', citizenid, count, totalCost))
    end)
end)

-- ==========================================
-- SELL CATTLE
-- ==========================================

RegisterNetEvent('tlw_cattle:sellCattle', function(locationId, cattleAlive, distance)
    local source = source
    
    -- Rate limit
    if not CheckRateLimit(source, 'sell', Config.Security.cooldown_sell or 2000) then
        return
    end
    
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check for active contract
    if not activeContracts[citizenid] then
        TriggerClientEvent('tlw_cattle:sellFailed', source, 'No active herd')
        return
    end
    
    local contract = activeContracts[citizenid]
    
    -- Validate distance (anti-exploit)
    if Config.Security.server_validates_distance then
        -- Could add more validation here
        distance = math.max(0, tonumber(distance) or 0)
    end
    
    -- Validate cattle count
    cattleAlive = tonumber(cattleAlive) or 0
    if cattleAlive > contract.herd_size then
        Utils.Debug('Exploit attempt: more cattle than started with')
        cattleAlive = contract.herd_size
    end
    
    if cattleAlive <= 0 then
        TriggerClientEvent('tlw_cattle:sellFailed', source, Config.Messages.sell_none)
        return
    end
    
    -- Calculate time taken
    local timeTaken = os.time() - contract.start_time
    
    -- Calculate survival rate
    local survivalRate = cattleAlive / contract.herd_size
    
    -- Load player data for level bonuses
    LoadPlayerData(source, function(playerData)
        if not playerData then
            TriggerClientEvent('tlw_cattle:sellFailed', source, 'Data error')
            return
        end
        
        -- Calculate payout
        local isNight = Utils.IsNightTime()
        local payout, breakdown = Pricing.CalculateSellPrice(
            contract.cattle_type,
            locationId,
            playerData.level,
            cattleAlive,
            distance,
            survivalRate,
            timeTaken,
            isNight
        )
        
        -- Subtract cowboy costs
        payout = payout - (contract.cowboy_cost or 0)
        payout = math.max(0, payout)
        
        -- Calculate XP earned
        local xpEarned = 0
        if Config.XP then
            -- Base XP
            xpEarned = xpEarned + (cattleAlive * Config.XP.per_cattle_sold)
            
            -- Distance XP
            local distanceKm = Utils.MetersToKm(distance)
            xpEarned = xpEarned + math.floor(distanceKm * Config.XP.per_km_driven)
            
            -- Perfect delivery bonus
            if survivalRate >= 1.0 then
                xpEarned = xpEarned + Config.XP.perfect_delivery
            end
            
            -- Time active XP
            local minutesActive = math.floor(timeTaken / 60)
            xpEarned = xpEarned + (minutesActive * Config.XP.per_minute_active)
        end
        
        -- Give money
        Player.Functions.AddMoney('cash', payout, 'cattle-sale')
        
        -- Update player stats
        local cattleLost = contract.herd_size - cattleAlive
        local perfectDelivery = (survivalRate >= 1.0) and 1 or 0
        
        DB.UpdatePlayerStats(citizenid, {
            total_deliveries = 1,
            cattle_saved = cattleAlive,
            cattle_lost = cattleLost,
            total_earned = payout,
            total_distance = distance,
            perfect_deliveries = perfectDelivery
        })
        
        -- Update XP and level
        local newXP = playerData.xp + xpEarned
        local newLevel = Utils.GetLevelFromXP(newXP)
        local leveledUp = newLevel > playerData.level
        
        DB.UpdatePlayerXP(citizenid, newXP, newLevel, function()
            -- Update cache
            playerData.xp = newXP
            playerData.level = newLevel
            playerDataCache[citizenid] = playerData
            
            -- Notify client
            TriggerClientEvent('tlw_cattle:playerDataLoaded', source, playerData)
            
            if leveledUp then
                -- Level up notification
                local benefit = Config.XP.benefits[newLevel]
                local benefitText = benefit and benefit.description or ''
                TriggerClientEvent('tlw_cattle:levelUp', source, newLevel, benefitText)
            end
        end)
        
        -- Complete contract in database
        DB.CompleteContract(contract.token, payout, 'completed')
        
        -- Record sale in market (affects demand)
        Pricing.RecordSale(locationId, cattleAlive)
        
        -- Notify client of successful sale
        TriggerClientEvent('tlw_cattle:sellSuccess', source, {
            payout = payout,
            cattle_sold = cattleAlive,
            cattle_lost = cattleLost,
            xp_earned = xpEarned,
            survival_rate = survivalRate,
            distance = distance,
            time_taken = timeTaken,
            breakdown = breakdown
        })
        
        -- Clear active contract
        activeContracts[citizenid] = nil
        
        Utils.Debug(string.format('Player %s sold %d/%d cattle for $%d (+%d XP)', 
            citizenid, cattleAlive, contract.herd_size, payout, xpEarned))
    end)
end)

-- ==========================================
-- CONTRACT MANAGEMENT
-- ==========================================

-- Update contract progress (distance, cattle count)
RegisterNetEvent('tlw_cattle:updateProgress', function(data)
    local source = source
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if activeContracts[citizenid] then
        if data.distance then
            activeContracts[citizenid].distance_traveled = data.distance
        end
        
        if data.cattle_alive then
            activeContracts[citizenid].cattle_alive = data.cattle_alive
        end
        
        -- Update database periodically (not every update to reduce load)
        if math.random() < 0.1 then -- 10% chance
            DB.UpdateContractProgress(activeContracts[citizenid].token, data)
        end
    end
end)

-- Rustler encounter completed
RegisterNetEvent('tlw_cattle:rustlerEncounter', function(defeated, cattleStolen)
    local source = source
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if activeContracts[citizenid] then
        -- Update cattle count
        if cattleStolen > 0 then
            activeContracts[citizenid].cattle_alive = math.max(0, activeContracts[citizenid].cattle_alive - cattleStolen)
        end
        
        -- Award XP if defeated
        if defeated > 0 then
            LoadPlayerData(source, function(playerData)
                if playerData then
                    local xpEarned = defeated * (Config.Rustlers.rewards.xp_per_kill or 30)
                    local newXP = playerData.xp + xpEarned
                    local newLevel = Utils.GetLevelFromXP(newXP)
                    
                    DB.UpdatePlayerXP(citizenid, newXP, newLevel)
                    DB.UpdatePlayerStats(citizenid, {rustlers_defeated = defeated})
                    
                    playerData.xp = newXP
                    playerData.level = newLevel
                    playerDataCache[citizenid] = playerData
                    
                    TriggerClientEvent('tlw_cattle:playerDataLoaded', source, playerData)
                end
            end)
        end
    end
end)

-- Mission failed (player killed cattle)
RegisterNetEvent('tlw_cattle:missionFailed', function(contractToken, reason)
    local source = source
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Verify contract exists and belongs to player
    if not activeContracts[citizenid] then
        return
    end
    
    local contract = activeContracts[citizenid]
    
    -- Verify token matches (security check)
    if contract.token ~= contractToken then
        Utils.Debug('Token mismatch in mission failure')
        return
    end
    
    Utils.Debug(string.format('Mission failed for player %s. Reason: %s', citizenid, reason))
    
    -- Mark contract as failed in database
    DB.CompleteContract(contract.token, 0, 'failed')
    
    -- Update player stats (track failed deliveries)
    -- Note: We track 1 failed delivery, but cattle_lost should reflect actual losses
    -- Since the mission was terminated early, we lose all remaining cattle
    DB.UpdatePlayerStats(citizenid, {
        failed_deliveries = 1,
        cattle_lost = contract.cattle_alive or contract.herd_size
    })
    
    -- Clear active contract
    activeContracts[citizenid] = nil
end)

-- ==========================================
-- CLIENT REQUESTS
-- ==========================================

-- Request current market prices
RegisterNetEvent('tlw_cattle:requestPrices', function()
    local source = source
    TriggerClientEvent('tlw_cattle:pricesUpdated', source, Pricing.GetAllPrices())
end)

-- Request market info (for UI)
RegisterNetEvent('tlw_cattle:requestMarketInfo', function()
    local source = source
    local marketInfo = Pricing.GetMarketInfo()
    TriggerClientEvent('tlw_cattle:marketInfo', source, marketInfo)
end)

-- Request player stats
RegisterNetEvent('tlw_cattle:requestStats', function()
    local source = source
    LoadPlayerData(source, function(data)
        if data then
            TriggerClientEvent('tlw_cattle:playerStats', source, data)
        end
    end)
end)

-- Request active contract info
RegisterNetEvent('tlw_cattle:requestContractInfo', function()
    local source = source
    local Player = GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if activeContracts[citizenid] then
        TriggerClientEvent('tlw_cattle:contractInfo', source, activeContracts[citizenid])
    else
        TriggerClientEvent('tlw_cattle:contractInfo', source, nil)
    end
end)

-- ==========================================
-- ADMIN COMMANDS
-- ==========================================

-- Only register commands if framework is loaded
if CoreObject and CoreObject.Commands then

-- Set player XP
CoreObject.Commands.Add(Config.Admin.commands.setxp or 'cattle_setxp', 'Set player cattle XP (Admin)', {{name = 'id', help = 'Player ID'}, {name = 'xp', help = 'XP Amount'}}, false, function(source, args)
    local targetId = tonumber(args[1])
    local xp = tonumber(args[2])
    
    if not targetId or not xp then
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Usage: /cattle_setxp <id> <xp>'}})
        return
    end
    
    local TargetPlayer = CoreObject.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Player not found'}})
        return
    end
    
    local citizenid = TargetPlayer.PlayerData.citizenid
    local newLevel = Utils.GetLevelFromXP(xp)
    
    DB.UpdatePlayerXP(citizenid, xp, newLevel, function(success)
        if success then
            if playerDataCache[citizenid] then
                playerDataCache[citizenid].xp = xp
                playerDataCache[citizenid].level = newLevel
            end
            
            TriggerClientEvent('tlw_cattle:playerDataLoaded', targetId, {xp = xp, level = newLevel})
            TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', string.format('Set player XP to %d (Level %d)', xp, newLevel)}})
        end
    end)
end, 'admin')

-- Set market demand
CoreObject.Commands.Add(Config.Admin.commands.setdemand or 'cattle_setdemand', 'Set market demand (Admin)', {{name = 'location', help = 'Location ID'}, {name = 'demand', help = 'Demand (0.5-2.0)'}}, false, function(source, args)
    local location = args[1]
    local demand = tonumber(args[2])
    
    if not location or not demand then
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Usage: /cattle_setdemand <location> <demand>'}})
        return
    end
    
    if Pricing.SetMarketDemand(location, demand) then
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', string.format('Set %s demand to %.2f', location, demand)}})
    else
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Location not found'}})
    end
end, 'admin')

-- Toggle debug mode
CoreObject.Commands.Add(Config.Admin.commands.debug or 'cattle_debug', 'Toggle debug mode (Admin)', {}, false, function(source, args)
    Config.Debug = not Config.Debug
    TriggerClientEvent('tlw_cattle:debugMode', -1, Config.Debug)
    TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Debug mode: ' .. (Config.Debug and 'ON' or 'OFF')}})
end, 'admin')

-- Reset player data
CoreObject.Commands.Add(Config.Admin.commands.reset_player or 'cattle_reset', 'Reset player cattle data (Admin)', {{name = 'id', help = 'Player ID'}}, false, function(source, args)
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Usage: /cattle_reset <id>'}})
        return
    end
    
    local TargetPlayer = CoreObject.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Player not found'}})
        return
    end
    
    local citizenid = TargetPlayer.PlayerData.citizenid
    
    DB.ResetPlayerData(citizenid, function(success)
        if success then
            playerDataCache[citizenid] = nil
            TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Player data reset'}})
        end
    end)
end, 'admin')

-- Force price update
CoreObject.Commands.Add('cattle_updateprices', 'Force price update (Admin)', {}, false, function(source, args)
    Pricing.ForceUpdate()
    TriggerClientEvent('chat:addMessage', source, {args = {'[Cattle]', 'Prices updated'}})
end, 'admin')

else
    print('^1[TLW Cattle Herding]^7 WARNING: Admin commands not registered - no framework loaded')
end

Utils.Debug('Server main loaded')
