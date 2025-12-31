--[[
    Player Controls for tlw_cattle_herding
    Handles speed/direction influence on herd
]]

-- Import from main
local activeHerd = nil

-- Update reference (called from main.lua if needed, or we can access via exports)
-- For now, we'll access the global if main.lua exports it

-- ==========================================
-- SPEED CONTROL
-- ==========================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Only active when herding
        if exports['Cattle-Herding']:IsHerdActive() then
            -- Speed increase
            if IsControlJustPressed(0, Config.PlayerControl.speed_keys.increase) then
                exports['Cattle-Herding']:AdjustHerdSpeed(Config.PlayerControl.speed_adjustment)
                Utils.Notify('Herd speed increased', 'info')
            end
            
            -- Speed decrease
            if IsControlJustPressed(0, Config.PlayerControl.speed_keys.decrease) then
                exports['Cattle-Herding']:AdjustHerdSpeed(-Config.PlayerControl.speed_adjustment)
                Utils.Notify('Herd speed decreased', 'info')
            end
            
            -- Direction bias left
            if IsControlJustPressed(0, Config.PlayerControl.direction_keys.left) then
                exports['Cattle-Herding']:ApplyDirectionBias(-Config.PlayerControl.bias_strength)
                Utils.Notify('Steering left', 'info')
            end
            
            -- Direction bias right
            if IsControlJustPressed(0, Config.PlayerControl.direction_keys.right) then
                exports['Cattle-Herding']:ApplyDirectionBias(Config.PlayerControl.bias_strength)
                Utils.Notify('Steering right', 'info')
            end
        else
            -- Not herding, sleep longer
            Citizen.Wait(1000)
        end
    end
end)

-- ==========================================
-- HELPER TEXT
-- ==========================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        
        if exports['Cattle-Herding']:IsHerdActive() then
            -- Show control hints periodically
            if math.random() < 0.1 then -- 10% chance every 5 seconds
                local hints = {
                    'Use Arrow Keys to control herd speed and direction',
                    'Position yourself behind the herd for best results',
                    'Avoid galloping near cattle - they will panic',
                    'Watch for stragglers breaking away from the herd',
                }
                
                local hint = hints[math.random(#hints)]
                -- Could show as help text here
            end
        else
            Citizen.Wait(10000)
        end
    end
end)

Utils.Debug('Controls module loaded')
