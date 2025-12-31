--[[
    NUI Bridge for tlw_cattle_herding
    Handles communication between Lua and web UI
]]

local nuiOpen = false
local currentScreen = nil

-- ==========================================
-- NUI FUNCTIONS
-- ==========================================

function OpenNUI(screen, data)
    if nuiOpen then return end
    
    nuiOpen = true
    currentScreen = screen
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        screen = screen,
        data = data or {}
    })
end

function CloseNUI()
    if not nuiOpen then return end
    
    nuiOpen = false
    currentScreen = nil
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

-- ==========================================
-- NUI CALLBACKS
-- ==========================================

RegisterNUICallback('close', function(data, cb)
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('buyCattle', function(data, cb)
    Utils.Debug('NUI: Buy cattle', data.type, data.count, data.location)
    
    -- Send to server
    TriggerServerEvent('tlw_cattle:buyCattle', data.type, data.count, data.location)
    
    CloseNUI()
    cb('ok')
end)

RegisterNUICallback('hireCowboys', function(data, cb)
    Utils.Debug('NUI: Hire cowboys', data.count)
    
    TriggerServerEvent('tlw_cattle:hireCowboys', data.count)
    
    cb('ok')
end)

RegisterNUICallback('requestPrices', function(data, cb)
    -- Request fresh prices from server
    TriggerServerEvent('tlw_cattle:requestMarketInfo')
    
    cb('ok')
end)

RegisterNUICallback('requestStats', function(data, cb)
    -- Request player stats
    TriggerServerEvent('tlw_cattle:requestStats')
    
    cb('ok')
end)

-- ==========================================
-- SERVER RESPONSES
-- ==========================================

RegisterNetEvent('tlw_cattle:marketInfo', function(info)
    if nuiOpen then
        SendNUIMessage({
            action = 'updateMarketInfo',
            data = info
        })
    end
end)

RegisterNetEvent('tlw_cattle:playerStats', function(stats)
    if nuiOpen then
        SendNUIMessage({
            action = 'updatePlayerStats',
            data = stats
        })
    end
end)

-- ==========================================
-- COMMANDS TO OPEN UI
-- ==========================================

RegisterCommand('cattlemenu', function()
    if not exports['Cattle-Herding']:IsHerdActive() then
        OpenNUI('contract_board', {
            player_level = playerLevel or 1
        })
    else
        Utils.Notify('Cannot open menu while herding', 'error')
    end
end, false)

RegisterCommand('cattleprices', function()
    -- Request market info then open
    TriggerServerEvent('tlw_cattle:requestMarketInfo')
    
    Citizen.SetTimeout(500, function()
        OpenNUI('market_prices')
    end)
end, false)

RegisterCommand('cattlestats', function()
    TriggerServerEvent('tlw_cattle:requestStats')
    
    Citizen.SetTimeout(500, function()
        OpenNUI('player_stats')
    end)
end, false)

-- ==========================================
-- EXPORTS
-- ==========================================

exports('OpenNUI', OpenNUI)
exports('CloseNUI', CloseNUI)
exports('IsNUIOpen', function() return nuiOpen end)

Utils.Debug('NUI module loaded')
