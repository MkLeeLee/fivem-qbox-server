local SPEED_FACTOR = Config.speedUnit == 'kmh' and 3.6 or 2.236936
local SPEED_LABEL = Config.speedUnit == 'kmh' and 'KM/H' or 'MPH'
local MPH_FACTOR = 2.236936
local KNOTS_FACTOR = 1.943844
local FEET_FACTOR = 3.28084

-- Vehicle classes with no seatbelt: motorcycles, cycles, boats, helicopters, planes
local NO_BELT_CLASS = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true }

-- How far the minimap moves up to make room for the status bars (fraction of screen height)
local MAP_LIFT = 0.040

local COMPASS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function isLoggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

-- Hunger, thirst and stress are statebags in Qbox; player metadata is the fallback
local function need(name, default)
    local value = LocalPlayer.state[name]
    if value ~= nil then return value end

    local data = exports.qbx_core:GetPlayerData()
    if data and data.metadata and data.metadata[name] ~= nil then
        return data.metadata[name]
    end
    return default
end

local function currentVehicle(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    return vehicle ~= 0 and vehicle or nil
end

-- ---------------------------------------------------------------- minimap

local function setupMinimap()
    -- GTA's stock map layout, lifted by MAP_LIFT
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045, 0.002 - MAP_LIFT, 0.150, 0.188888)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.020, 0.032 - MAP_LIFT, 0.111, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.03, 0.022 - MAP_LIFT, 0.266, 0.237)
    SetBigmapActive(true, false)
    Wait(50)
    SetBigmapActive(false, false)
end

-- Where the map sits on screen, so the page can line the bars up beneath it
local function sendMapAnchor()
    local safeZone = GetSafeZoneSize()
    local margin = (1.0 / 20.0) * (math.abs(safeZone - 1.0) * 10)
    SendNUIMessage({
        action = 'anchor',
        left = margin + 0.004,
        width = 1.0 / (4 * GetAspectRatio(false)) - 0.004,
        bottom = margin + MAP_LIFT - 0.030,
    })
end

CreateThread(function()
    while not isLoggedIn() do Wait(500) end
    setupMinimap()
    sendMapAnchor()

    local minimap = RequestScaleformMovie('minimap')
    while not HasScaleformMovieLoaded(minimap) do Wait(50) end

    while true do
        Wait(0)
        for _, component in ipairs({ 3, 4, 6, 7, 8, 9 }) do
            HideHudComponentThisFrame(component) -- cash, vehicle name, area, class, street
        end
        BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR') -- removes GTA's own bars
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
    end
end)

-- ---------------------------------------------------------------- visibility

CreateThread(function()
    local shown
    while true do
        Wait(250)
        local show = isLoggedIn() and not IsPauseMenuActive() and not IsScreenFadedOut()
        if show ~= shown then
            shown = show
            SendNUIMessage({ action = 'visible', show = show })
        end
        local inVehicle = currentVehicle(PlayerPedId()) ~= nil
        DisplayRadar(show and (Config.mapOnFoot or inVehicle))
    end
end)

-- ---------------------------------------------------------------- player stats

CreateThread(function()
    while true do
        Wait(250)
        if isLoggedIn() then
            local ped = PlayerPedId()
            local player = PlayerId()
            local stamina = IsPedSwimmingUnderWater(ped)
                and GetPlayerUnderwaterTimeRemaining(player) * 10
                or 100 - GetPlayerSprintStaminaRemaining(player)
            local maxHealth = math.max(GetEntityMaxHealth(ped) - 100, 1)
            local proximity = LocalPlayer.state.proximity

            SendNUIMessage({
                action = 'player',
                health = clamp((GetEntityHealth(ped) - 100) / maxHealth * 100, 0, 100),
                armor = clamp(GetPedArmour(ped), 0, 100),
                hunger = clamp(need('hunger', 100), 0, 100),
                thirst = clamp(need('thirst', 100), 0, 100),
                stress = clamp(need('stress', 0), 0, 100),
                stamina = clamp(stamina, 0, 100),
                talking = NetworkIsPlayerTalking(player),
                voiceRange = proximity and proximity.distance or 0,
            })
        end
    end
end)

-- ---------------------------------------------------------------- location

CreateThread(function()
    while true do
        Wait(500)
        if isLoggedIn() then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local street = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local index = math.floor(((360.0 - GetEntityHeading(ped)) % 360 + 22.5) / 45) % 8 + 1

            SendNUIMessage({
                action = 'location',
                direction = COMPASS[index],
                street = GetStreetNameFromHashKey(street),
                area = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)),
            })
        end
    end
end)

-- ---------------------------------------------------------------- vehicles

local function landingGear(vehicle)
    if not GetVehicleHasLandingGear(vehicle) then return 'none' end
    local state = GetLandingGearState(vehicle)
    if state == 0 then return 'down' end
    if state == 4 then return 'up' end
    return 'moving'
end

CreateThread(function()
    local mode = 'none'
    local warnedFuel = false

    while true do
        local vehicle = isLoggedIn() and currentVehicle(PlayerPedId()) or nil
        if not vehicle then
            if mode ~= 'none' then
                mode = 'none'
                SendNUIMessage({ action = 'mode', mode = mode })
            end
            warnedFuel = false
            Wait(300)
        else
            local class = GetVehicleClass(vehicle)
            local newMode = (class == 15 or class == 16) and 'air' or 'car'
            if newMode ~= mode then
                mode = newMode
                SendNUIMessage({ action = 'mode', mode = mode })
            end

            local running = GetIsVehicleEngineRunning(vehicle)
            local fuel = clamp(GetVehicleFuelLevel(vehicle), 0, 100)
            local engine = clamp(GetVehicleEngineHealth(vehicle) / 10, 0, 100)

            if fuel < Config.lowFuelWarning and not warnedFuel then
                warnedFuel = true
                exports.qbx_core:Notify('Low fuel', 'error')
            elseif fuel >= Config.lowFuelWarning then
                warnedFuel = false
            end

            if mode == 'air' then
                local coords = GetEntityCoords(vehicle)
                local roll = GetEntityRoll(vehicle)
                SendNUIMessage({
                    action = 'air',
                    speed = GetEntitySpeed(vehicle) * KNOTS_FACTOR,
                    altitude = coords.z * FEET_FACTOR,
                    agl = GetEntityHeightAboveGround(vehicle) * FEET_FACTOR,
                    pitch = GetEntityPitch(vehicle),
                    roll = Config.invertRoll and -roll or roll,
                    gear = landingGear(vehicle),
                    engine = engine,
                    running = running,
                })
            else
                local _, lightsOn, highBeams = GetVehicleLightsState(vehicle)
                local rpm = running and GetVehicleCurrentRpm(vehicle) or 0.0
                SendNUIMessage({
                    action = 'car',
                    speed = GetEntitySpeed(vehicle) * SPEED_FACTOR,
                    unit = SPEED_LABEL,
                    rpm = rpm,
                    fuel = fuel,
                    engine = engine,
                    running = running,
                    hasBelt = not NO_BELT_CLASS[class],
                    belt = LocalPlayer.state.seatbelt == true or LocalPlayer.state.harness == true,
                    lights = lightsOn == 1 or highBeams == 1,
                })
            end
            Wait(100)
        end
    end
end)

-- ---------------------------------------------------------------- stress

if Config.stress.enabled then
    -- Speeding
    CreateThread(function()
        while true do
            Wait(Config.stress.speedCooldown * 1000)
            local vehicle = isLoggedIn() and currentVehicle(PlayerPedId())
            if vehicle and GetEntitySpeed(vehicle) * MPH_FACTOR > Config.stress.speedLimitMph then
                TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
            end
        end
    end)

    -- Shooting
    CreateThread(function()
        local nextGain = 0
        while true do
            Wait(0)
            if IsPedShooting(PlayerPedId()) and GetGameTimer() >= nextGain then
                nextGain = GetGameTimer() + Config.stress.shootCooldown * 1000
                TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
            end
        end
    end)

    -- Screen effects, stronger and more often as stress rises
    CreateThread(function()
        while true do
            local stress = isLoggedIn() and need('stress', 0) or 0
            if stress >= Config.stress.minForEffects then
                local strength = (stress - Config.stress.minForEffects) / (100 - Config.stress.minForEffects)
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.03 + strength * 0.09)
                TriggerScreenblurFadeIn(800.0)
                Wait(800 + math.floor(strength * 1000))
                TriggerScreenblurFadeOut(800.0)
                Wait(math.floor(30000 - strength * 20000))
            else
                Wait(5000)
            end
        end
    end)
end
