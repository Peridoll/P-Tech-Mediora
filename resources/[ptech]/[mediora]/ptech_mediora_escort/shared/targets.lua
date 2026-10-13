-- Shared classification: client selection and server authorization use the same rules.
EscortRules = {}

local function matches(state, rules)
    for _, rule in ipairs(rules or {}) do
        local value = state[rule.key]
        for _, expected in ipairs(rule.values) do
            if value == expected then return true end
        end
    end
    return false
end

local function metadataMatches(metadata, keys)
    for _, key in ipairs(keys or {}) do
        if metadata[key] == true then return true end
    end
    return false
end

function EscortRules.playerStatus(state, metadata, health)
    local rules = Config.Targets.players
    metadata = metadata or {}
    return {
        cuffed = matches(state, rules.cuffed.state) or metadataMatches(metadata, rules.cuffed.metadata),
        down = matches(state, rules.down.state) or metadataMatches(metadata, rules.down.metadata),
        dead = matches(state, rules.dead.state) or metadataMatches(metadata, rules.dead.metadata)
            or (rules.dead.healthAtOrBelow ~= false and health ~= nil and health <= rules.dead.healthAtOrBelow),
    }
end

function EscortRules.npcStatus(state, health, engineDead)
    local rules = Config.Targets.npcs
    return {
        cuffed = false,
        down = matches(state, rules.down.state)
            or (rules.down.healthAtOrBelow ~= false and health ~= nil and health <= rules.down.healthAtOrBelow),
        dead = engineDead == true or (health ~= nil and health <= 100), -- NPC health has a 100 baseline; never treat a corpse as normal.
    }
end

function EscortRules.allowed(status, npc)
    local rules = npc and Config.Targets.npcs or Config.Targets.players
    if npc and (not rules.enabled or status.dead) then return false end
    if status.cuffed and not rules.cuffed.allow then return false end
    if status.dead and not rules.dead.allow then return false end
    if status.down and not status.dead and not rules.down.allow then return false end
    if status.cuffed or status.down or status.dead then return true end
    return rules.allowNormal == true
end

function EscortRules.restrained(status)
    return status.cuffed or status.down or status.dead
end

function EscortRules.distance(action)
    local distances = Config.Distances
    -- Support the user's current normalCarry / vehicleCarry names.
    local value = distances[action] or distances[action:sub(1, 4) == 'walk' and 'normalCarry' or 'vehicleCarry']
    assert(type(value) == 'number' and value > 0, 'Invalid escort distance: ' .. action)
    return value
end
