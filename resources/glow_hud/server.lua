-- Other Qbox resources raise and lower stress through these events, which qbx_hud used to own.
local function changeStress(src, amount)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local current = player.PlayerData.metadata.stress or 0
    local value = math.max(0, math.min(100, current + amount))
    player.Functions.SetMetaData('stress', value)
    TriggerClientEvent('hud:client:UpdateStress', src, value)
end

local function validAmount(amount)
    return type(amount) == 'number' and amount > 0 and amount <= 100
end

RegisterNetEvent('hud:server:GainStress', function(amount)
    if Config.stress.enabled and validAmount(amount) then
        changeStress(source, amount)
    end
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    if Config.stress.enabled and validAmount(amount) then
        changeStress(source, -amount)
    end
end)

local function showMoney(src, account, label)
    local player = exports.qbx_core:GetPlayer(src)
    if player then
        exports.qbx_core:Notify(src, ('%s: $%d'):format(label, player.PlayerData.money[account] or 0), 'inform')
    end
end

RegisterCommand('cash', function(src) showMoney(src, 'cash', 'Cash') end, false)
RegisterCommand('bank', function(src) showMoney(src, 'bank', 'Bank') end, false)
