Config = {
    speedUnit = 'mph',      -- 'mph' or 'kmh'
    mapOnFoot = true,       -- false = only show the minimap in vehicles
    lowFuelWarning = 20,    -- percent; shows a notification once when fuel drops below this
    invertRoll = false,     -- set true if the flight horizon tilts the wrong way

    stress = {
        enabled = true,
        speedLimitMph = 110,    -- driving faster than this slowly raises stress
        speedCooldown = 10,     -- seconds between speed stress gains
        shootCooldown = 8,      -- seconds between shooting stress gains
        minForEffects = 50,     -- screen blur and shake start at this stress level
    },
}
