--[[
    Shared Utilities for tlw_cattle_herding
    Functions used by both client and server
]]

Utils = {}

-- Calculate distance between two vectors
function Utils.GetDistance(coord1, coord2)
    if not coord1 or not coord2 then return 0.0 end
    return #(vector3(coord1.x, coord1.y, coord1.z) - vector3(coord2.x, coord2.y, coord2.z))
end

-- Calculate 2D distance (ignoring Z)
function Utils.GetDistance2D(coord1, coord2)
    if not coord1 or not coord2 then return 0.0 end
    local dx = coord1.x - coord2.x
    local dy = coord1.y - coord2.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Convert meters to kilometers
function Utils.MetersToKm(meters)
    return meters / 1000.0
end

-- Format money with commas
function Utils.FormatMoney(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return '$' .. formatted
end

-- Round number to decimal places
function Utils.Round(num, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Get current in-game hour
function Utils.GetGameHour()
    return GetClockHours()
end

-- Check if it's nighttime
function Utils.IsNightTime()
    local hour = Utils.GetGameHour()
    return hour >= 20 or hour < 6
end

-- Calculate XP required for a level
function Utils.GetXPForLevel(level)
    if Config.XP and Config.XP.levels then
        return Config.XP.levels[level] or 0
    end
    return 0
end

-- Calculate level from XP
function Utils.GetLevelFromXP(xp)
    if not Config.XP or not Config.XP.levels then return 1 end
    
    local level = 1
    for lvl = #Config.XP.levels, 1, -1 do
        if xp >= Config.XP.levels[lvl] then
            level = lvl
            break
        end
    end
    return level
end

-- Get random point in circle
function Utils.GetRandomPointInCircle(center, radius)
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * radius
    
    return vector3(
        center.x + distance * math.cos(angle),
        center.y + distance * math.sin(angle),
        center.z
    )
end

-- Get random point in radius with ground check
function Utils.GetRandomGroundPoint(center, minDist, maxDist)
    local angle = math.random() * 2 * math.pi
    local distance = minDist + math.random() * (maxDist - minDist)
    
    local x = center.x + distance * math.cos(angle)
    local y = center.y + distance * math.sin(angle)
    local z = center.z
    
    -- Try to find ground
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 100.0, 0)
    if foundGround then
        z = groundZ
    end
    
    return vector3(x, y, z)
end

-- Calculate herd centroid (center point)
function Utils.GetHerdCentroid(cattleEntities)
    if not cattleEntities or #cattleEntities == 0 then return nil end
    
    local sumX, sumY, sumZ = 0, 0, 0
    local count = 0
    
    for _, entity in pairs(cattleEntities) do
        if DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            sumX = sumX + coords.x
            sumY = sumY + coords.y
            sumZ = sumZ + coords.z
            count = count + 1
        end
    end
    
    if count == 0 then return nil end
    
    return vector3(sumX / count, sumY / count, sumZ / count)
end

-- Generate secure token
function Utils.GenerateToken()
    local charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local token = ''
    for i = 1, 32 do
        local rand = math.random(#charset)
        token = token .. string.sub(charset, rand, rand)
    end
    return token
end

-- Check if player is in area
function Utils.IsPlayerInArea(playerCoords, areaCoords, radius)
    return Utils.GetDistance(playerCoords, areaCoords) <= radius
end

-- Get cattle type by model
function Utils.GetCattleTypeByModel(model)
    if not Config.Cattle or not Config.Cattle.types then return nil end
    
    for _, cattleType in ipairs(Config.Cattle.types) do
        if cattleType.model == model or GetHashKey(cattleType.model) == model then
            return cattleType
        end
    end
    return nil
end

-- Get location by ID
function Utils.GetLocationById(locations, id)
    for _, location in ipairs(locations) do
        if location.id == id or location.name == id then
            return location
        end
    end
    return nil
end

-- Clamp value between min and max
function Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Lerp (linear interpolation)
function Utils.Lerp(a, b, t)
    return a + (b - a) * Utils.Clamp(t, 0, 1)
end

-- Get heading between two points
function Utils.GetHeadingFromCoords(coord1, coord2)
    local dx = coord2.x - coord1.x
    local dy = coord2.y - coord1.y
    local heading = math.deg(math.atan2(dy, dx))
    return (heading + 360) % 360
end

-- Notification helper (if available)
function Utils.Notify(message, type)
    if IsDuplicityVersion() then
        -- Server side
        return
    end
    
    -- Try RSG-Core notification
    if GetResourceState('rsg-core') == 'started' then
        local RSGCore = exports['rsg-core']:GetCoreObject()
        if RSGCore and RSGCore.Functions and RSGCore.Functions.Notify then
            RSGCore.Functions.Notify(message, type or 'primary')
            return
        end
    end
    
    -- Fallback to chat
    TriggerEvent('chat:addMessage', {
        args = {'[Cattle]', message}
    })
end

-- Debug print
function Utils.Debug(...)
    if Config.Debug then
        local args = {...}
        local message = '[Cattle Debug]'
        for _, v in ipairs(args) do
            message = message .. ' ' .. tostring(v)
        end
        print(message)
    end
end

-- Table contains value
function Utils.TableContains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Get random table element
function Utils.GetRandomFromTable(table)
    if not table or #table == 0 then return nil end
    return table[math.random(#table)]
end

-- Deep copy table
function Utils.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.DeepCopy(orig_key)] = Utils.DeepCopy(orig_value)
        end
        setmetatable(copy, Utils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

return Utils
