--[[
    Database Layer for tlw_cattle_herding
    Handles all MySQL queries with oxmysql
]]

DB = {}

-- Initialize database (run on resource start)
function DB.Init()
    Utils.Debug('Database layer initialized')
end

-- ==========================================
-- PLAYER DATA QUERIES
-- ==========================================

-- Get or create player data
function DB.GetPlayerData(citizenid, callback)
    MySQL.Async.fetchAll('SELECT * FROM tlw_cattle_players WHERE citizenid = ?', {citizenid}, function(result)
        if result and result[1] then
            callback(result[1])
        else
            -- Create new player record
            DB.CreatePlayerData(citizenid, function(success)
                if success then
                    DB.GetPlayerData(citizenid, callback)
                else
                    callback(nil)
                end
            end)
        end
    end)
end

-- Create new player data
function DB.CreatePlayerData(citizenid, callback)
    MySQL.Async.execute('INSERT INTO tlw_cattle_players (citizenid, xp, level) VALUES (?, 0, 1)', 
    {citizenid}, function(affectedRows)
        callback(affectedRows > 0)
    end)
end

-- Update player XP and level
function DB.UpdatePlayerXP(citizenid, xp, level, callback)
    MySQL.Async.execute('UPDATE tlw_cattle_players SET xp = ?, level = ?, updated_at = NOW() WHERE citizenid = ?',
    {xp, level, citizenid}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Update player statistics
function DB.UpdatePlayerStats(citizenid, stats, callback)
    local query = 'UPDATE tlw_cattle_players SET '
    local params = {}
    local updates = {}
    
    if stats.total_deliveries then
        table.insert(updates, 'total_deliveries = total_deliveries + ?')
        table.insert(params, stats.total_deliveries)
    end
    
    if stats.cattle_saved then
        table.insert(updates, 'cattle_saved = cattle_saved + ?')
        table.insert(params, stats.cattle_saved)
    end
    
    if stats.cattle_lost then
        table.insert(updates, 'cattle_lost = cattle_lost + ?')
        table.insert(params, stats.cattle_lost)
    end
    
    if stats.rustlers_defeated then
        table.insert(updates, 'rustlers_defeated = rustlers_defeated + ?')
        table.insert(params, stats.rustlers_defeated)
    end
    
    if stats.total_earned then
        table.insert(updates, 'total_earned = total_earned + ?')
        table.insert(params, stats.total_earned)
    end
    
    if stats.total_distance then
        table.insert(updates, 'total_distance = total_distance + ?')
        table.insert(params, stats.total_distance)
    end
    
    if stats.perfect_deliveries then
        table.insert(updates, 'perfect_deliveries = perfect_deliveries + ?')
        table.insert(params, stats.perfect_deliveries)
    end
    
    if stats.failed_deliveries then
        table.insert(updates, 'failed_deliveries = failed_deliveries + ?')
        table.insert(params, stats.failed_deliveries)
    end
    
    query = query .. table.concat(updates, ', ') .. ', updated_at = NOW() WHERE citizenid = ?'
    table.insert(params, citizenid)
    
    MySQL.Async.execute(query, params, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Reset player data (admin command)
function DB.ResetPlayerData(citizenid, callback)
    MySQL.Async.execute('UPDATE tlw_cattle_players SET xp = 0, level = 1, total_deliveries = 0, cattle_saved = 0, cattle_lost = 0, rustlers_defeated = 0, total_earned = 0, total_distance = 0, perfect_deliveries = 0 WHERE citizenid = ?',
    {citizenid}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- ==========================================
-- MARKET DATA QUERIES
-- ==========================================

-- Get all market data
function DB.GetAllMarkets(callback)
    MySQL.Async.fetchAll('SELECT * FROM tlw_cattle_market', {}, function(result)
        callback(result or {})
    end)
end

-- Get market by location
function DB.GetMarket(location_id, callback)
    MySQL.Async.fetchAll('SELECT * FROM tlw_cattle_market WHERE location_id = ?', {location_id}, function(result)
        callback(result and result[1] or nil)
    end)
end

-- Update market demand
function DB.UpdateMarketDemand(location_id, demand, callback)
    MySQL.Async.execute('UPDATE tlw_cattle_market SET demand = ?, last_update = NOW() WHERE location_id = ?',
    {demand, location_id}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Update market price multiplier
function DB.UpdateMarketPrice(location_id, multiplier, callback)
    MySQL.Async.execute('UPDATE tlw_cattle_market SET price_multiplier = ?, last_update = NOW() WHERE location_id = ?',
    {multiplier, location_id}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Record sale at market
function DB.RecordMarketSale(location_id, callback)
    MySQL.Async.execute('UPDATE tlw_cattle_market SET total_sales = total_sales + 1, last_sale_time = NOW(), last_update = NOW() WHERE location_id = ?',
    {location_id}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- ==========================================
-- CONTRACT QUERIES
-- ==========================================

-- Create new contract
function DB.CreateContract(contractData, callback)
    local query = [[
        INSERT INTO tlw_cattle_contracts 
        (citizenid, contract_token, cattle_type, herd_size, buy_location, buy_price_total, cattle_alive, cowboys_hired, cowboy_cost)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    MySQL.Async.insert(query, {
        contractData.citizenid,
        contractData.contract_token,
        contractData.cattle_type,
        contractData.herd_size,
        contractData.buy_location,
        contractData.buy_price_total,
        contractData.herd_size, -- cattle_alive starts as herd_size
        contractData.cowboys_hired or 0,
        contractData.cowboy_cost or 0
    }, function(insertId)
        callback(insertId)
    end)
end

-- Get active contract for player
function DB.GetActiveContract(citizenid, callback)
    MySQL.Async.fetchAll('SELECT * FROM tlw_cattle_contracts WHERE citizenid = ? AND status = ? ORDER BY started_at DESC LIMIT 1',
    {citizenid, 'active'}, function(result)
        callback(result and result[1] or nil)
    end)
end

-- Get contract by token
function DB.GetContractByToken(token, callback)
    MySQL.Async.fetchAll('SELECT * FROM tlw_cattle_contracts WHERE contract_token = ?', {token}, function(result)
        callback(result and result[1] or nil)
    end)
end

-- Update contract progress
function DB.UpdateContractProgress(token, data, callback)
    local updates = {}
    local params = {}
    
    if data.cattle_alive then
        table.insert(updates, 'cattle_alive = ?')
        table.insert(params, data.cattle_alive)
    end
    
    if data.distance_traveled then
        table.insert(updates, 'distance_traveled = ?')
        table.insert(params, data.distance_traveled)
    end
    
    if data.rustler_encounters then
        table.insert(updates, 'rustler_encounters = rustler_encounters + ?')
        table.insert(params, data.rustler_encounters)
    end
    
    if data.sell_location then
        table.insert(updates, 'sell_location = ?')
        table.insert(params, data.sell_location)
    end
    
    if #updates == 0 then
        if callback then callback(false) end
        return
    end
    
    local query = 'UPDATE tlw_cattle_contracts SET ' .. table.concat(updates, ', ') .. ' WHERE contract_token = ?'
    table.insert(params, token)
    
    MySQL.Async.execute(query, params, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Complete contract
function DB.CompleteContract(token, payout, status, callback)
    MySQL.Async.execute([[
        UPDATE tlw_cattle_contracts 
        SET status = ?, final_payout = ?, completed_at = NOW() 
        WHERE contract_token = ?
    ]], {status or 'completed', payout, token}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Abandon contract
function DB.AbandonContract(token, callback)
    MySQL.Async.execute('UPDATE tlw_cattle_contracts SET status = ?, completed_at = NOW() WHERE contract_token = ?',
    {'abandoned', token}, function(affectedRows)
        if callback then callback(affectedRows > 0) end
    end)
end

-- Get player contract history
function DB.GetContractHistory(citizenid, limit, callback)
    limit = limit or 10
    MySQL.Async.fetchAll('SELECT * FROM tlw_cattle_contracts WHERE citizenid = ? ORDER BY started_at DESC LIMIT ?',
    {citizenid, limit}, function(result)
        callback(result or {})
    end)
end

-- Clean up old contracts (admin maintenance)
function DB.CleanOldContracts(days, callback)
    days = days or 30
    MySQL.Async.execute('DELETE FROM tlw_cattle_contracts WHERE completed_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
    {days}, function(affectedRows)
        if callback then callback(affectedRows) end
    end)
end

-- ==========================================
-- LEADERBOARD QUERIES
-- ==========================================

-- Get top players by XP
function DB.GetTopPlayersByXP(limit, callback)
    limit = limit or 10
    MySQL.Async.fetchAll('SELECT citizenid, xp, level, total_deliveries, total_earned FROM tlw_cattle_players ORDER BY xp DESC LIMIT ?',
    {limit}, function(result)
        callback(result or {})
    end)
end

-- Get top players by deliveries
function DB.GetTopPlayersByDeliveries(limit, callback)
    limit = limit or 10
    MySQL.Async.fetchAll('SELECT citizenid, total_deliveries, cattle_saved, perfect_deliveries FROM tlw_cattle_players ORDER BY total_deliveries DESC LIMIT ?',
    {limit}, function(result)
        callback(result or {})
    end)
end

-- ==========================================
-- STATISTICS QUERIES
-- ==========================================

-- Get server-wide statistics
function DB.GetServerStats(callback)
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(DISTINCT citizenid) as total_players,
            SUM(total_deliveries) as total_deliveries,
            SUM(cattle_saved) as total_cattle_saved,
            SUM(cattle_lost) as total_cattle_lost,
            SUM(rustlers_defeated) as total_rustlers_defeated,
            SUM(total_earned) as total_money_earned,
            AVG(level) as avg_level
        FROM tlw_cattle_players
    ]], {}, function(result)
        callback(result and result[1] or {})
    end)
end

Utils.Debug('Database module loaded')

return DB
