-- Client-side script for Cattle Herding
local playerXP = 0
local playerLevel = 1
local currentHerd = {}
local isHerding = false
local showHUD = Config.EnableHUD
local showUI = Config.EnableUI
local cattlePrices = {}

-- Prompt variables
local herdPrompt = nil
local shopPrompt = nil

-- Initialize prompts for controller support
Citizen.CreateThread(function()
    if Config.ControllerSupport then
        -- Create herding prompt
        local str = 'Herd Cattle'
        herdPrompt = Citizen.InvokeNative(0x04F97DE45A519419) -- PromptRegisterBegin
        Citizen.InvokeNative(0xE5F2C8C6D49B9E45, herdPrompt, str) -- PromptSetText
        Citizen.InvokeNative(0x5DD02A8318420DD7, herdPrompt, Config.HerdingButton) -- PromptSetControlAction
        Citizen.InvokeNative(0xC5F428EE08FA7F2C, herdPrompt, true) -- PromptSetEnabled
        Citizen.InvokeNative(0xF7AA2696A22AD8B9, herdPrompt) -- PromptSetVisible
        Citizen.InvokeNative(0x8A0FB4D03A630D21, herdPrompt, true) -- PromptSetHoldMode
        Citizen.InvokeNative(0xF4A5C4509BF923B1, herdPrompt, Citizen.ResultAsString()) -- PromptRegisterEnd
    end
end)

-- Draw HUD
function DrawHUD()
    if not showHUD then return end
    
    local text = string.format("Level: %d | XP: %d | Cattle: %d/%d", 
        playerLevel, playerXP, #currentHerd, Config.MaxHerdSize)
    
    SetTextScale(0.35, 0.35)
    SetTextColor(255, 255, 255, 255)
    SetTextCentre(false)
    SetTextDropshadow(1, 0, 0, 0, 255)
    
    SetTextFontForCurrentCommand(1)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), Config.HUDPosition.x, Config.HUDPosition.y)
end

-- Get nearest cattle
function GetNearestCattle()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearestCattle = nil
    local nearestDistance = Config.HerdingRadius
    
    for _, model in ipairs(Config.CattleModels) do
        local hash = GetHashKey(model)
        local cattle = GetClosestPed(playerCoords.x, playerCoords.y, playerCoords.z, Config.HerdingRadius, hash, false, false)
        
        if DoesEntityExist(cattle) then
            local cattleCoords = GetEntityCoords(cattle)
            local distance = #(playerCoords - cattleCoords)
            
            if distance < nearestDistance then
                nearestDistance = distance
                nearestCattle = cattle
            end
        end
    end
    
    return nearestCattle, nearestDistance
end

-- Add cattle to herd
function AddCattleToHerd(cattle)
    if #currentHerd >= Config.MaxHerdSize then
        TriggerEvent('chat:addMessage', {
            args = {'Cattle Herding', 'Your herd is full!'}
        })
        return false
    end
    
    table.insert(currentHerd, cattle)
    TriggerServerEvent('cattleherding:addXP', Config.HerdingXPPerCattle)
    
    -- Make cattle follow player
    TaskFollowToOffsetOfEntity(cattle, PlayerPedId(), 0.0, -3.0 - (#currentHerd * 2), 0.0, Config.HerdingSpeed, -1, 2.0, true)
    
    return true
end

-- Herding main loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        DrawHUD()
        
        if Config.ControllerSupport and herdPrompt then
            local cattle, distance = GetNearestCattle()
            
            if cattle and distance < 5.0 then
                Citizen.InvokeNative(0xF7AA2696A22AD8B9, herdPrompt, true) -- Show prompt
                
                if Citizen.InvokeNative(0xE0F65F0640EF0617, herdPrompt) then -- Check if prompt completed
                    if AddCattleToHerd(cattle) then
                        isHerding = true
                        TriggerEvent('chat:addMessage', {
                            args = {'Cattle Herding', 'Cattle added to herd!'}
                        })
                    end
                end
            end
        end
    end
end)

-- Cattle shop interaction
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        for _, shop in ipairs(Config.CattleShops) do
            local distance = #(playerCoords - shop.coords)
            
            if distance < 3.0 then
                if not showUI then
                    Citizen.Wait(1000)
                    goto continue
                end
                
                -- Draw marker
                Citizen.InvokeNative(0x2A32FAA57B937173, 0x50638AB9, shop.coords.x, shop.coords.y, shop.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, 255, 0, 0, 100, false, false, 2, false, nil, nil, false)
                
                if distance < 2.0 then
                    -- Show help text
                    SetTextScale(0.35, 0.35)
                    SetTextColor(255, 255, 255, 255)
                    local text = "Press ~INPUT_CONTEXT~ to open " .. shop.name
                    DisplayText(CreateVarString(10, "LITERAL_STRING", text), 0.5, 0.9)
                    
                    if IsControlJustPressed(0, 0xE8342FF2) then -- E key / Cross button
                        OpenCattleShop(shop)
                    end
                end
            end
            ::continue::
        end
    end
end)

-- Open cattle shop menu
function OpenCattleShop(shop)
    TriggerServerEvent('cattleherding:openShop', #currentHerd)
end

-- Handle XP updates from server
RegisterNetEvent('cattleherding:updateXP')
AddEventHandler('cattleherding:updateXP', function(xp, level)
    playerXP = xp
    playerLevel = level
end)

-- Handle price updates from server
RegisterNetEvent('cattleherding:updatePrices')
AddEventHandler('cattleherding:updatePrices', function(prices)
    cattlePrices = prices
end)

-- Handle sell result
RegisterNetEvent('cattleherding:sellResult')
AddEventHandler('cattleherding:sellResult', function(success, amount, xp)
    if success then
        -- Clear herd
        for _, cattle in ipairs(currentHerd) do
            if DoesEntityExist(cattle) then
                DeleteEntity(cattle)
            end
        end
        currentHerd = {}
        isHerding = false
        
        TriggerEvent('chat:addMessage', {
            args = {'Cattle Herding', string.format('Sold cattle for $%d! +%d XP', amount, xp)}
        })
    else
        TriggerEvent('chat:addMessage', {
            args = {'Cattle Herding', 'Failed to sell cattle!'}
        })
    end
end)

-- Toggle HUD command
RegisterCommand('togglecattlehud', function()
    showHUD = not showHUD
    TriggerEvent('chat:addMessage', {
        args = {'Cattle Herding', 'HUD ' .. (showHUD and 'enabled' or 'disabled')}
    })
end, false)

-- Toggle UI command
RegisterCommand('togglecattleui', function()
    showUI = not showUI
    TriggerEvent('chat:addMessage', {
        args = {'Cattle Herding', 'UI ' .. (showUI and 'enabled' or 'disabled')}
    })
end, false)

-- Create blips for cattle shops
Citizen.CreateThread(function()
    for _, shop in ipairs(Config.CattleShops) do
        if shop.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, shop.coords.x, shop.coords.y, shop.coords.z) -- BlipAddForCoords
            SetBlipSprite(blip, -1230993421, true) -- Cattle icon
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, shop.name) -- SetBlipName
        end
    end
end)

-- AI Cowboys encounter
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        
        if Config.EnableAICowboys and isHerding and math.random() < Config.CowboySpawnChance then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local spawnCoords = GetRandomCoordNearPlayer(playerCoords, 50.0, 100.0)
            
            if spawnCoords then
                SpawnAICowboy(spawnCoords)
            end
        end
    end
end)

-- Rustlers encounter
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(120000) -- Check every 2 minutes
        
        if Config.EnableRustlers and isHerding and #currentHerd > 0 and math.random() < Config.RustlerSpawnChance then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local spawnCoords = GetRandomCoordNearPlayer(playerCoords, 50.0, 100.0)
            
            if spawnCoords then
                SpawnRustler(spawnCoords)
            end
        end
    end
end)

-- Spawn AI Cowboy
function SpawnAICowboy(coords)
    local model = Config.CowboyModels[math.random(#Config.CowboyModels)]
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Citizen.Wait(100)
    end
    
    local cowboy = CreatePed(hash, coords.x, coords.y, coords.z, math.random(0, 360), false, false, false, false)
    SetEntityAsMissionEntity(cowboy, true, true)
    SetPedRelationshipGroupHash(cowboy, GetHashKey("PLAYER"))
    
    -- Make cowboy greet player
    TaskWanderStandard(cowboy, 10.0, 10)
    
    TriggerEvent('chat:addMessage', {
        args = {'Cattle Herding', 'A friendly cowboy has appeared!'}
    })
end

-- Spawn Rustler
function SpawnRustler(coords)
    local model = Config.RustlerModels[math.random(#Config.RustlerModels)]
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Citizen.Wait(100)
    end
    
    local rustler = CreatePed(hash, coords.x, coords.y, coords.z, math.random(0, 360), false, false, false, false)
    SetEntityAsMissionEntity(rustler, true, true)
    SetPedRelationshipGroupHash(rustler, GetHashKey("ENEMY"))
    
    -- Give weapon to rustler
    GiveWeaponToPed(rustler, GetHashKey("WEAPON_REVOLVER_CATTLEMAN"), 100, true, true)
    
    -- Make rustler attack player
    TaskCombatPed(rustler, PlayerPedId(), 0, 16)
    
    TriggerEvent('chat:addMessage', {
        args = {'Cattle Herding', 'Rustlers are attacking your herd!'}
    })
    
    -- Monitor rustler death for reward
    Citizen.CreateThread(function()
        while DoesEntityExist(rustler) and not IsEntityDead(rustler) do
            Citizen.Wait(1000)
        end
        
        if IsEntityDead(rustler) then
            TriggerServerEvent('cattleherding:addXP', Config.RustlerReward)
            TriggerEvent('chat:addMessage', {
                args = {'Cattle Herding', 'Rustler defeated! +' .. Config.RustlerReward .. ' XP'}
            })
        end
    end)
end

-- Get random coordinates near player
function GetRandomCoordNearPlayer(playerCoords, minDistance, maxDistance)
    local angle = math.random() * 2 * math.pi
    local distance = minDistance + math.random() * (maxDistance - minDistance)
    
    local x = playerCoords.x + distance * math.cos(angle)
    local y = playerCoords.y + distance * math.sin(angle)
    local z = playerCoords.z
    
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 100.0, 0)
    if foundGround then
        z = groundZ
    end
    
    return vector3(x, y, z)
end
