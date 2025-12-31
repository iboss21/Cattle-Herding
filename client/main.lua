--[[
    Client Main Logic for tlw_cattle_herding
    Handles organic herd AI, spawning, grazing, cohesion, panic, and player interaction
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Player data
local playerData = {}
local playerLevel = 1

-- Active herd state
local activeHerd = {
    active = false,
    token = nil,
    entities = {},          -- Table of cattle entity IDs
    cattleData = {},        -- Per-cattle data (state, target, etc.)
    leader = nil,           -- Leader cattle entity
    centroid = nil,         -- Herd center point
    targetSpeed = 1.0,      -- Current target speed
    directionBias = 0.0,    -- Left/right bias (-1 to 1)
    biasDecay = 0,          -- Timer for bias decay
    startLocation = nil,
    startTime = 0,
    distanceTraveled = 0,
    lastUpdatePos = nil,
}

-- Straggler tracking
local stragglers = {}

-- Spawned AI cowboys
local aiCowboys = {}

-- UI state
local hudEnabled = true
local debugEnabled = false

-- Market prices (synced from server)
local marketPrices = {}

-- Prompts
local buyPrompt = nil
local sellPrompt = nil

-- ==========================================
-- INITIALIZATION
-- ==========================================

Citizen.CreateThread(function()
    Utils.Debug('Client initializing...')
    
    -- Request initial data from server
    TriggerServerEvent('tlw_cattle:requestStats')
    TriggerServerEvent('tlw_cattle:requestPrices')
    
    -- Create prompts
    CreatePrompts()
    
    -- Create blips
    CreateLocationBlips()
    
    print('^2[Cattle Herding]^7 Client started')
end)

-- ==========================================
-- SERVER EVENT HANDLERS
-- ==========================================

-- Player data loaded
RegisterNetEvent('tlw_cattle:playerDataLoaded', function(data)
    playerData = data
    playerLevel = data.level or 1
    Utils.Debug('Player data loaded: Level', playerLevel, 'XP', data.xp)
end)

-- Prices updated
RegisterNetEvent('tlw_cattle:pricesUpdated', function(prices)
    marketPrices = prices
    Utils.Debug('Market prices updated')
end)

-- Purchase successful
RegisterNetEvent('tlw_cattle:purchaseSuccess', function(data)
    Utils.Debug('Purchase successful:', data.count, data.cattle_type)
    
    -- Start spawning herd
    SpawnHerd(data.cattle_type, data.count, data.location, data.token)
    
    Utils.Notify(string.format(Config.Messages.purchase_success, data.count, data.cattle_type, data.cost), 'success')
end)

-- Purchase failed
RegisterNetEvent('tlw_cattle:buyFailed', function(reason)
    Utils.Notify(reason, 'error')
end)

-- Sell successful
RegisterNetEvent('tlw_cattle:sellSuccess', function(data)
    Utils.Debug('Sold cattle:', data.cattle_sold, 'for $', data.payout)
    
    -- Clean up herd
    CleanupHerd()
    
    local message = string.format(Config.Messages.sell_success, data.cattle_sold, data.payout, data.xp_earned)
    Utils.Notify(message, 'success')
end)

-- Level up
RegisterNetEvent('tlw_cattle:levelUp', function(level, benefit)
    Utils.Notify(string.format(Config.Messages.level_up, level), 'success')
    if benefit and benefit ~= '' then
        Utils.Notify(string.format(Config.Messages.level_perk, benefit), 'info')
    end
end)

-- Cowboys hired
RegisterNetEvent('tlw_cattle:cowboysHired', function(count, cost)
    SpawnAICowboys(count)
    Utils.Notify(string.format(Config.Messages.cowboy_hired, count, cost), 'success')
end)

-- Debug mode toggled
RegisterNetEvent('tlw_cattle:debugMode', function(enabled)
    debugEnabled = enabled
end)

-- ==========================================
-- LOCATION BLIPS
-- ==========================================

function CreateLocationBlips()
    -- Buy locations
    for _, location in ipairs(Config.BuyRanches or {}) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, location.prompt_coords.x, location.prompt_coords.y, location.prompt_coords.z)
        SetBlipSprite(blip, GetHashKey('blip_ambient_herd'), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, 'Buy Cattle: ' .. location.name)
    end
    
    -- Sell locations
    for _, location in ipairs(Config.SellYards or {}) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, location.coords.x, location.coords.y, location.coords.z)
        SetBlipSprite(blip, GetHashKey('blip_shop_butcher'), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, 'Sell Cattle: ' .. location.name)
    end
end

-- ==========================================
-- PROMPTS
-- ==========================================

function CreatePrompts()
    -- Buy prompt
    local buyStr = Config.Prompts.buy_cattle.text or 'Buy Cattle'
    buyPrompt = Citizen.InvokeNative(0x04F97DE45A519419)
    Citizen.InvokeNative(0x5DD02A8318420DD7, buyPrompt, Config.Prompts.buy_cattle.key)
    Citizen.InvokeNative(0xE5F2C8C6D49B9E45, buyPrompt, buyStr)
    Citizen.InvokeNative(0x8A0FB4D03A630D21, buyPrompt, true) -- Hold mode
    Citizen.InvokeNative(0xF4A5C4509BF923B1, buyPrompt)
    
    -- Sell prompt
    local sellStr = Config.Prompts.sell_cattle.text or 'Sell Herd'
    sellPrompt = Citizen.InvokeNative(0x04F97DE45A519419)
    Citizen.InvokeNative(0x5DD02A8318420DD7, sellPrompt, Config.Prompts.sell_cattle.key)
    Citizen.InvokeNative(0xE5F2C8C6D49B9E45, sellPrompt, sellStr)
    Citizen.InvokeNative(0x8A0FB4D03A630D21, sellPrompt, true) -- Hold mode
    Citizen.InvokeNative(0xF4A5C4509BF923B1, sellPrompt)
end

-- ==========================================
-- BUY CATTLE INTERACTION
-- ==========================================

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Check buy locations
        for _, location in ipairs(Config.BuyRanches or {}) do
            local distance = #(playerCoords - location.prompt_coords)
            
            if distance < 3.0 then
                sleep = 0
                
                -- Show prompt
                Citizen.InvokeNative(0xC5F428EE08FA7F2C, buyPrompt, true) -- SetEnabled
                Citizen.InvokeNative(0xF7AA2696A22AD8B9, buyPrompt, true) -- SetVisible
                
                -- Check if completed
                if Citizen.InvokeNative(0xE0F65F0640EF0617, buyPrompt) then
                    -- Open simple buy menu
                    OpenBuyMenu(location)
                end
                
                break
            end
        end
        
        if sleep > 0 then
            Citizen.InvokeNative(0xF7AA2696A22AD8B9, buyPrompt, false) -- Hide
        end
        
        Citizen.Wait(sleep)
    end
end)

-- Simple buy menu (no NUI, just native input)
function OpenBuyMenu(location)
    -- For now, use a simple approach - could be expanded to NUI later
    -- Quick buy: default to 5 cows
    
    if activeHerd.active then
        Utils.Notify(Config.Messages.buy_fail_active, 'error')
        return
    end
    
    -- Simple: Buy 5 cows by default (could add number input)
    local cattleType = Config.Cattle.types[1].model -- Default to first type
    local count = 5
    
    TriggerServerEvent('tlw_cattle:buyCattle', cattleType, count, location.name)
end

-- ==========================================
-- SPAWN HERD
-- ==========================================

function SpawnHerd(cattleModel, count, locationName, token)
    Utils.Debug('Spawning herd:', count, cattleModel)
    
    -- Find location
    local location = nil
    for _, loc in ipairs(Config.BuyRanches) do
        if loc.name == locationName then
            location = loc
            break
        end
    end
    
    if not location then
        Utils.Debug('Location not found:', locationName)
        return
    end
    
    -- Load model
    local hash = GetHashKey(cattleModel)
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do
        Citizen.Wait(50)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(hash) then
        Utils.Debug('Failed to load model:', cattleModel)
        return
    end
    
    -- Spawn cattle at pen locations
    activeHerd.entities = {}
    activeHerd.cattleData = {}
    activeHerd.token = token
    activeHerd.active = true
    activeHerd.startTime = GetGameTimer()
    activeHerd.startLocation = location.prompt_coords
    activeHerd.lastUpdatePos = location.prompt_coords
    activeHerd.distanceTraveled = 0
    
    local spawnPoints = location.spawn_points
    for i = 1, count do
        local spawnPos = spawnPoints[((i - 1) % #spawnPoints) + 1]
        
        -- Add slight random offset
        local offset = vector3(
            math.random(-1, 1) * 0.5,
            math.random(-1, 1) * 0.5,
            0
        )
        
        local finalPos = spawnPos + offset
        
        -- Spawn cattle
        local cattle = CreatePed(hash, finalPos.x, finalPos.y, finalPos.z, math.random(0, 360), false, false, false, false)
        
        if DoesEntityExist(cattle) then
            SetEntityAsMissionEntity(cattle, true, true)
            SetPedRelationshipGroupHash(cattle, GetHashKey('PLAYER'))
            SetBlockingOfNonTemporaryEvents(cattle, false)
            SetPedFleeAttributes(cattle, 0, false)
            SetPedCombatAttributes(cattle, 46, true) -- Can fight back
            
            -- Store cattle
            table.insert(activeHerd.entities, cattle)
            activeHerd.cattleData[cattle] = {
                state = 'idle',      -- idle, grazing, following, panicking, straggling
                target = nil,
                panicTimer = 0,
                grazeTimer = 0,
                lastPosition = finalPos,
            }
        end
    end
    
    -- Pick random leader
    if #activeHerd.entities > 0 then
        activeHerd.leader = activeHerd.entities[math.random(#activeHerd.entities)]
    end
    
    Utils.Debug('Spawned', #activeHerd.entities, 'cattle')
    Utils.Notify('Herd spawned! Get behind them to start herding.', 'success')
    
    -- Start herd AI
    StartHerdAI()
end

-- ==========================================
-- HERD AI SYSTEM (THE MAGIC)
-- ==========================================

function StartHerdAI()
    Citizen.CreateThread(function()
        while activeHerd.active do
            local updateInterval = Config.HerdBehavior.ai_update_interval or 500
            Citizen.Wait(updateInterval)
            
            -- Update herd centroid
            activeHerd.centroid = Utils.GetHerdCentroid(activeHerd.entities)
            
            if not activeHerd.centroid then
                -- No cattle left
                CleanupHerd()
                break
            end
            
            -- Get player info
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local playerOnHorse = IsPedOnMount(playerPed)
            
            -- Calculate player influence
            local playerInfluence = CalculatePlayerInfluence(playerCoords, activeHerd.centroid)
            
            -- Update each cattle
            for _, cattle in ipairs(activeHerd.entities) do
                if DoesEntityExist(cattle) and not IsEntityDead(cattle) then
                    UpdateCattleAI(cattle, playerCoords, playerInfluence, playerOnHorse)
                else
                    -- Remove dead/invalid cattle
                    activeHerd.cattleData[cattle] = nil
                end
            end
            
            -- Check for stragglers
            CheckForStragglers()
            
            -- Update distance traveled
            UpdateDistanceTraveled(activeHerd.centroid)
            
            -- Decay direction bias
            if activeHerd.biasDecay > 0 then
                activeHerd.biasDecay = activeHerd.biasDecay - (updateInterval / 1000)
                if activeHerd.biasDecay <= 0 then
                    activeHerd.directionBias = 0
                end
            end
        end
    end)
    
    -- Separate thread for cohesion (runs less frequently)
    Citizen.CreateThread(function()
        while activeHerd.active do
            Citizen.Wait(Config.HerdBehavior.cohesion_update_interval or 1000)
            
            ApplyCohesionForces()
        end
    end)
end

-- Calculate how player position/movement affects herd
function CalculatePlayerInfluence(playerCoords, herdCenter)
    if not herdCenter then return {strength = 0, direction = 0} end
    
    local distance = #(vector2(playerCoords.x, playerCoords.y) - vector2(herdCenter.x, herdCenter.y))
    local pressureRadius = Config.HerdBehavior.pressure_radius or 18.0
    
    if distance > pressureRadius then
        return {strength = 0, direction = 0, position = 'far'}
    end
    
    -- Determine player position relative to herd
    local angle = math.atan2(playerCoords.y - herdCenter.y, playerCoords.x - herdCenter.x)
    
    -- Calculate influence strength based on distance
    local optimalDist = Config.HerdBehavior.pressure_optimal_distance or 8.0
    local tooClose = Config.HerdBehavior.pressure_too_close or 3.0
    
    local strength = 0
    local position = 'beside'
    
    if distance < tooClose then
        strength = 1.0 -- Maximum pressure (bunching)
        position = 'too_close'
    elseif distance < optimalDist then
        strength = Utils.Lerp(0.5, 1.0, (optimalDist - distance) / (optimalDist - tooClose))
        position = 'optimal'
    else
        strength = Utils.Lerp(0.5, 0, (distance - optimalDist) / (pressureRadius - optimalDist))
        position = 'behind'
    end
    
    return {
        strength = strength,
        direction = angle,
        position = position,
        distance = distance
    }
end

-- Update individual cattle AI
function UpdateCattleAI(cattle, playerCoords, playerInfluence, playerOnHorse)
    local data = activeHerd.cattleData[cattle]
    if not data then return end
    
    local cattleCoords = GetEntityCoords(cattle)
    local heading = GetEntityHeading(cattle)
    
    -- Check for panic triggers
    if data.state ~= 'panicking' then
        if ShouldPanic(cattle, cattleCoords, playerCoords, playerOnHorse) then
            data.state = 'panicking'
            data.panicTimer = math.random(Config.HerdBehavior.panic_duration_min, Config.HerdBehavior.panic_duration_max)
            
            -- Spread panic to nearby cattle
            SpreadPanic(cattle, cattleCoords)
        end
    end
    
    -- Handle current state
    if data.state == 'panicking' then
        HandlePanicState(cattle, data, cattleCoords, playerCoords)
    elseif data.state == 'straggling' then
        HandleStragglingState(cattle, data, cattleCoords)
    elseif data.state == 'grazing' then
        HandleGrazingState(cattle, data)
    else
        -- Normal herding behavior
        HandleNormalState(cattle, data, cattleCoords, playerInfluence)
    end
    
    data.lastPosition = cattleCoords
end

-- Check if cattle should panic
function ShouldPanic(cattle, cattleCoords, playerCoords, playerOnHorse)
    local panicing = Config.HerdBehavior.panic
    
    -- Gunfire nearby
    if IsAnyPedShootingInArea(cattleCoords.x, cattleCoords.y, cattleCoords.z, panicing.triggers.gunshot_nearby, false, true) then
        return true
    end
    
    -- Player sprinting/galloping too close
    if playerOnHorse then
        local playerSpeed = GetEntitySpeed(PlayerPedId())
        if playerSpeed > 8.0 and #(playerCoords - cattleCoords) < panicing.triggers.player_sprinting_close then
            return true
        end
    end
    
    return false
end

-- Spread panic to nearby cattle
function SpreadPanic(sourceCattle, sourceCoords)
    local spreadRadius = Config.HerdBehavior.panic.spread_radius or 18.0
    local spreadChance = Config.HerdBehavior.panic.spread_chance or 0.4
    
    for _, otherCattle in ipairs(activeHerd.entities) do
        if otherCattle ~= sourceCattle and DoesEntityExist(otherCattle) then
            local otherCoords = GetEntityCoords(otherCattle)
            if #(sourceCoords - otherCoords) < spreadRadius then
                if math.random() < spreadChance then
                    local data = activeHerd.cattleData[otherCattle]
                    if data and data.state ~= 'panicking' then
                        data.state = 'panicking'
                        data.panicTimer = math.random(Config.HerdBehavior.panic.duration_min, Config.HerdBehavior.panic.duration_max)
                    end
                end
            end
        end
    end
end

-- Handle panicking cattle
function HandlePanicState(cattle, data, cattleCoords, playerCoords)
    data.panicTimer = data.panicTimer - (Config.HerdBehavior.ai_update_interval / 1000)
    
    if data.panicTimer <= 0 then
        -- Check if player is calm nearby
        local playerSpeed = GetEntitySpeed(PlayerPedId())
        if playerSpeed < 2.0 and #(cattleCoords - playerCoords) > 10.0 then
            data.state = 'idle'
            data.panicTimer = 0
            TaskStandStill(cattle, 2000)
        else
            data.panicTimer = 3 -- Stay panicked a bit longer
        end
    else
        -- Run away from player
        local fleePoint = Utils.GetRandomPointInCircle(cattleCoords, 20.0)
        TaskGoToCoordAnyMeans(cattle, fleePoint.x, fleePoint.y, fleePoint.z, Config.HerdBehavior.speed.panic, 0, false, 1, 10.0)
    end
end

-- Handle straggling cattle (returning to herd)
function HandleStragglingState(cattle, data, cattleCoords)
    if not activeHerd.centroid then
        data.state = 'idle'
        return
    end
    
    local distToHerd = #(cattleCoords - activeHerd.centroid)
    
    if distToHerd < Config.HerdBehavior.cohesion_radius then
        -- Back with herd
        data.state = 'idle'
        stragglers[cattle] = nil
    else
        -- Move toward herd
        TaskGoToCoordAnyMeans(cattle, activeHerd.centroid.x, activeHerd.centroid.y, activeHerd.centroid.z,
            Config.HerdBehavior.speed.trot * Config.HerdBehavior.straggler_return_speed_multiplier,
            0, false, 1, 10.0)
    end
end

-- Handle grazing cattle
function HandleGrazingState(cattle, data)
    data.grazeTimer = data.grazeTimer - (Config.HerdBehavior.ai_update_interval / 1000)
    
    if data.grazeTimer <= 0 then
        data.state = 'idle'
        ClearPedTasks(cattle)
    else
        -- Stay grazing (head down animation would be here if available)
        if not IsPedStill(cattle) then
            TaskStandStill(cattle, 5000)
        end
    end
end

-- Handle normal herding state
function HandleNormalState(cattle, data, cattleCoords, playerInfluence)
    -- Check if should start grazing (when not being pressured)
    if playerInfluence.strength < 0.2 and Config.HerdBehavior.idle_enabled then
        if math.random() < (Config.HerdBehavior.graze_probability or 0.75) then
            data.state = 'grazing'
            data.grazeTimer = math.random(Config.HerdBehavior.graze_duration.min, Config.HerdBehavior.graze_duration.max)
            TaskStartScenarioInPlace(cattle, GetHashKey("WORLD_ANIMAL_EAT"), 0, true, false, 0, false)
            return
        end
    end
    
    -- Follow behavior
    if cattle == activeHerd.leader then
        -- Leader moves forward based on player influence and speed setting
        if playerInfluence.strength > 0.1 then
            local moveSpeed = activeHerd.targetSpeed * Config.HerdBehavior.speed.walk
            local direction = playerInfluence.direction + math.pi + (activeHerd.directionBias * 0.5) -- Opposite of player
            
            local targetPoint = vector3(
                cattleCoords.x + math.cos(direction) * 5.0,
                cattleCoords.y + math.sin(direction) * 5.0,
                cattleCoords.z
            )
            
            TaskGoToCoordAnyMeans(cattle, targetPoint.x, targetPoint.y, targetPoint.z, moveSpeed, 0, false, 1, 10.0)
        end
    else
        -- Other cattle follow leader or stay near herd center
        local followTarget = activeHerd.leader
        if DoesEntityExist(followTarget) then
            local leaderCoords = GetEntityCoords(followTarget)
            local distToLeader = #(cattleCoords - leaderCoords)
            
            if distToLeader > Config.HerdBehavior.follow_distance * 2 then
                -- Move toward leader
                TaskGoToCoordAnyMeans(cattle, leaderCoords.x, leaderCoords.y, leaderCoords.z,
                    activeHerd.targetSpeed * Config.HerdBehavior.speed.walk,
                    0, false, 1, 10.0)
            elseif distToLeader < Config.HerdBehavior.separation_min then
                -- Too close, move away slightly
                local awayDir = math.atan2(cattleCoords.y - leaderCoords.y, cattleCoords.x - leaderCoords.x)
                local movePoint = vector3(
                    cattleCoords.x + math.cos(awayDir) * 2.0,
                    cattleCoords.y + math.sin(awayDir) * 2.0,
                    cattleCoords.z
                )
                TaskGoToCoordAnyMeans(cattle, movePoint.x, movePoint.y, movePoint.z, Config.HerdBehavior.speed.walk, 0, false, 1, 5.0)
            end
        end
    end
end

-- Apply cohesion forces (keep herd together)
function ApplyCohesionForces()
    if not activeHerd.centroid then return end
    
    for _, cattle in ipairs(activeHerd.entities) do
        if DoesEntityExist(cattle) and not IsEntityDead(cattle) then
            local data = activeHerd.cattleData[cattle]
            if data and data.state ~= 'panicking' and data.state ~= 'grazing' then
                local cattleCoords = GetEntityCoords(cattle)
                local distFromCenter = #(cattleCoords - activeHerd.centroid)
                
                if distFromCenter > Config.HerdBehavior.cohesion_radius then
                    -- Pull toward center
                    TaskGoToCoordAnyMeans(cattle, activeHerd.centroid.x, activeHerd.centroid.y, activeHerd.centroid.z,
                        Config.HerdBehavior.speed.trot, 0, false, 1, 10.0)
                end
            end
        end
    end
end

-- Check for stragglers
function CheckForStragglers()
    if not activeHerd.centroid then return end
    
    local currentTime = GetGameTimer()
    
    for _, cattle in ipairs(activeHerd.entities) do
        if DoesEntityExist(cattle) and not IsEntityDead(cattle) then
            local cattleCoords = GetEntityCoords(cattle)
            local distFromHerd = #(cattleCoords - activeHerd.centroid)
            
            if distFromHerd > Config.HerdBehavior.straggler_threshold then
                -- Mark as straggler
                if not stragglers[cattle] then
                    stragglers[cattle] = currentTime
                    local data = activeHerd.cattleData[cattle]
                    if data then
                        data.state = 'straggling'
                    end
                else
                    -- Check timeout
                    local stragglingTime = (currentTime - stragglers[cattle]) / 1000
                    if stragglingTime > Config.HerdBehavior.straggler_timeout then
                        -- Lost permanently
                        Utils.Notify(Config.Messages.lost:format(1), 'error')
                        DeleteEntity(cattle)
                        stragglers[cattle] = nil
                        
                        -- Remove from active herd
                        for i, ent in ipairs(activeHerd.entities) do
                            if ent == cattle then
                                table.remove(activeHerd.entities, i)
                                break
                            end
                        end
                    end
                end
            elseif stragglers[cattle] then
                -- No longer straggling
                stragglers[cattle] = nil
                local data = activeHerd.cattleData[cattle]
                if data and data.state == 'straggling' then
                    data.state = 'idle'
                end
            end
        end
    end
end

-- Update distance traveled
function UpdateDistanceTraveled(currentCenter)
    if not currentCenter or not activeHerd.lastUpdatePos then return end
    
    local distance = #(currentCenter - activeHerd.lastUpdatePos)
    
    -- Only count if significant movement (not just wandering)
    if distance > 5.0 then
        activeHerd.distanceTraveled = activeHerd.distanceTraveled + distance
        activeHerd.lastUpdatePos = currentCenter
        
        -- Periodically update server
        if math.random() < 0.1 then
            TriggerServerEvent('tlw_cattle:updateProgress', {
                distance = activeHerd.distanceTraveled,
                cattle_alive = #activeHerd.entities
            })
        end
    end
end

-- ==========================================
-- SELL CATTLE INTERACTION
-- ==========================================

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        
        if activeHerd.active and activeHerd.centroid then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Check sell locations
            for _, location in ipairs(Config.SellYards or {}) do
                local distance = #(playerCoords - location.coords)
                
                if distance < location.radius then
                    -- Check if herd is also in radius
                    local herdDist = #(activeHerd.centroid - location.coords)
                    
                    if herdDist < location.radius then
                        sleep = 0
                        
                        -- Show prompt
                        Citizen.InvokeNative(0xC5F428EE08FA7F2C, sellPrompt, true)
                        Citizen.InvokeNative(0xF7AA2696A22AD8B9, sellPrompt, true)
                        
                        -- Check if completed
                        if Citizen.InvokeNative(0xE0F65F0640EF0617, sellPrompt) then
                            SellHerd(location.id or location.name)
                        end
                        
                        break
                    end
                end
            end
        end
        
        if sleep > 0 then
            Citizen.InvokeNative(0xF7AA2696A22AD8B9, sellPrompt, false)
        end
        
        Citizen.Wait(sleep)
    end
end)

function SellHerd(locationId)
    if not activeHerd.active then return end
    
    -- Count alive cattle
    local aliveCount = 0
    for _, cattle in ipairs(activeHerd.entities) do
        if DoesEntityExist(cattle) and not IsEntityDead(cattle) then
            aliveCount = aliveCount + 1
        end
    end
    
    if aliveCount == 0 then
        Utils.Notify(Config.Messages.sell_none, 'error')
        return
    end
    
    -- Send to server for processing
    TriggerServerEvent('tlw_cattle:sellCattle', locationId, aliveCount, activeHerd.distanceTraveled)
end

-- ==========================================
-- CLEANUP
-- ==========================================

function CleanupHerd()
    Utils.Debug('Cleaning up herd')
    
    -- Delete all cattle entities
    for _, cattle in ipairs(activeHerd.entities) do
        if DoesEntityExist(cattle) then
            DeleteEntity(cattle)
        end
    end
    
    -- Delete AI cowboys
    for _, cowboy in ipairs(aiCowboys) do
        if DoesEntityExist(cowboy) then
            DeleteEntity(cowboy)
        end
    end
    
    -- Reset state
    activeHerd = {
        active = false,
        token = nil,
        entities = {},
        cattleData = {},
        leader = nil,
        centroid = nil,
        targetSpeed = 1.0,
        directionBias = 0.0,
        biasDecay = 0,
        startLocation = nil,
        startTime = 0,
        distanceTraveled = 0,
        lastUpdatePos = nil,
    }
    
    stragglers = {}
    aiCowboys = {}
end

-- ==========================================
-- AI COWBOYS
-- ==========================================

function SpawnAICowboys(count)
    if not activeHerd.active or not activeHerd.centroid then return end
    
    -- Cleanup existing
    for _, cowboy in ipairs(aiCowboys) do
        if DoesEntityExist(cowboy) then
            DeleteEntity(cowboy)
        end
    end
    aiCowboys = {}
    
    -- Spawn new cowboys
    local models = Config.AICowboys.models or {}
    
    for i = 1, count do
        local modelName = models[math.random(#models)]
        local hash = GetHashKey(modelName)
        
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Citizen.Wait(50)
        end
        
        -- Spawn near herd
        local spawnPos = Utils.GetRandomPointInCircle(activeHerd.centroid, 10.0)
        local cowboy = CreatePed(hash, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), false, false, false, false)
        
        if DoesEntityExist(cowboy) then
            SetEntityAsMissionEntity(cowboy, true, true)
            SetPedRelationshipGroupHash(cowboy, GetHashKey('PLAYER'))
            
            -- Give weapon
            GiveWeaponToPed(cowboy, GetHashKey(Config.AICowboys.behavior.weapon or 'WEAPON_REVOLVER_CATTLEMAN'), 100, false, true)
            
            table.insert(aiCowboys, cowboy)
        end
    end
    
    Utils.Debug('Spawned', #aiCowboys, 'AI cowboys')
end

-- AI Cowboy behavior (basic positioning)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Update every 5 seconds
        
        if #aiCowboys > 0 and activeHerd.active and activeHerd.centroid then
            for i, cowboy in ipairs(aiCowboys) do
                if DoesEntityExist(cowboy) then
                    -- Position cowboys around herd
                    local offset = Config.AICowboys.behavior.side_flank_offset or 8.0
                    local angle = (i / #aiCowboys) * 2 * math.pi
                    
                    local targetPos = vector3(
                        activeHerd.centroid.x + math.cos(angle) * offset,
                        activeHerd.centroid.y + math.sin(angle) * offset,
                        activeHerd.centroid.z
                    )
                    
                    TaskGoToCoordAnyMeans(cowboy, targetPos.x, targetPos.y, targetPos.z, 2.0, 0, false, 1, 10.0)
                end
            end
        end
    end
end)

-- ==========================================
-- HUD
-- ==========================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.HUD.update_every_ms or 1000)
        
        if hudEnabled and Config.HUD.enabled and activeHerd.active then
            DrawHerdHUD()
        end
    end
end)

function DrawHerdHUD()
    local aliveCount = 0
    for _, cattle in ipairs(activeHerd.entities) do
        if DoesEntityExist(cattle) and not IsEntityDead(cattle) then
            aliveCount = aliveCount + 1
        end
    end
    
    local stragglerCount = 0
    for _ in pairs(stragglers) do
        stragglerCount = stragglerCount + 1
    end
    
    -- Determine state
    local state = 'Calm'
    local color = Config.HUD.text_normal
    
    for _, cattle in ipairs(activeHerd.entities) do
        local data = activeHerd.cattleData[cattle]
        if data and data.state == 'panicking' then
            state = 'Panicking!'
            color = Config.HUD.text_danger
            break
        elseif data and data.state == 'grazing' then
            state = 'Grazing'
        end
    end
    
    if stragglerCount > 0 then
        color = Config.HUD.text_warning
    end
    
    -- Build HUD text
    local text = string.format('Herd: %d | %s', aliveCount, state)
    
    if stragglerCount > 0 then
        text = text .. string.format(' | ⚠ %d Stragglers', stragglerCount)
    end
    
    if Config.HUD.show_level then
        text = text .. string.format(' | Lvl %d', playerLevel)
    end
    
    -- Draw text
    SetTextScale(0.35, 0.35)
    SetTextColor(color[1], color[2], color[3], color[4])
    SetTextCentre(false)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextFontForCurrentCommand(1)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), Config.HUD.position.x, Config.HUD.position.y)
end

-- Toggle HUD
RegisterCommand('togglecattlehud', function()
    hudEnabled = not hudEnabled
    Utils.Notify('HUD ' .. (hudEnabled and 'enabled' or 'disabled'), 'info')
end, false)

-- ==========================================
-- DEBUG VISUALIZATION
-- ==========================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if debugEnabled and Config.Debug and activeHerd.active then
            -- Draw herd centroid
            if activeHerd.centroid then
                DrawMarker(28, activeHerd.centroid.x, activeHerd.centroid.y, activeHerd.centroid.z, 
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                    1.0, 1.0, 1.0, 
                    0, 255, 0, 100, false, false, 2, false, nil, nil, false)
                
                -- Draw cohesion circle
                DrawMarker(1, activeHerd.centroid.x, activeHerd.centroid.y, activeHerd.centroid.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    Config.HerdBehavior.cohesion_radius * 2, Config.HerdBehavior.cohesion_radius * 2, 1.0,
                    0, 255, 0, 50, false, false, 2, false, nil, nil, false)
            end
            
            -- Draw lines to stragglers
            for cattle in pairs(stragglers) do
                if DoesEntityExist(cattle) then
                    local cattleCoords = GetEntityCoords(cattle)
                    DrawLine(activeHerd.centroid.x, activeHerd.centroid.y, activeHerd.centroid.z,
                        cattleCoords.x, cattleCoords.y, cattleCoords.z,
                        255, 0, 0, 255)
                end
            end
        end
    end
end)

-- ==========================================
-- EXPORTS FOR OTHER MODULES
-- ==========================================

exports('IsHerdActive', function()
    return activeHerd.active
end)

exports('AdjustHerdSpeed', function(amount)
    if not activeHerd.active then return end
    
    activeHerd.targetSpeed = Utils.Clamp(
        activeHerd.targetSpeed + amount,
        Config.PlayerControl.speed_range.min,
        Config.PlayerControl.speed_range.max
    )
    
    Utils.Debug('Herd speed adjusted to:', activeHerd.targetSpeed)
end)

exports('ApplyDirectionBias', function(bias)
    if not activeHerd.active then return end
    
    activeHerd.directionBias = Utils.Clamp(bias, -1.0, 1.0)
    activeHerd.biasDecay = Config.PlayerControl.bias_decay_time or 4.0
    
    Utils.Debug('Direction bias applied:', activeHerd.directionBias)
end)

exports('GetHerdInfo', function()
    if not activeHerd.active then return nil end
    
    local aliveCount = 0
    for _, cattle in ipairs(activeHerd.entities) do
        if DoesEntityExist(cattle) and not IsEntityDead(cattle) then
            aliveCount = aliveCount + 1
        end
    end
    
    return {
        active = activeHerd.active,
        cattle_count = aliveCount,
        centroid = activeHerd.centroid,
        distance_traveled = activeHerd.distanceTraveled,
        straggler_count = Utils.TableLength(stragglers)
    }
end)

Utils.Debug('Client main loaded')
