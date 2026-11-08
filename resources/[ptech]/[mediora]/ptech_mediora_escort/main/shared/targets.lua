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

-- 外部リソース連携用。true以外（文字列/数値を含む）は許可しない。
function EscortRules.hasCarryableTag(state)
    for _, key in ipairs(Config.CarryableTags or {}) do
        if state[key] == true then return true end
    end
    return false
end

function EscortRules.playerStatus(state, metadata, health)
    local rules = Config.Targets.players
    metadata = metadata or {}
    return {
        down = matches(state, rules.down.state) or metadataMatches(metadata, rules.down.metadata),
        dead = matches(state, rules.dead.state) or metadataMatches(metadata, rules.dead.metadata)
            or (rules.dead.healthAtOrBelow ~= false and health ~= nil and health <= rules.dead.healthAtOrBelow),
        carryable = EscortRules.hasCarryableTag(state),
    }
end

function EscortRules.npcStatus(state, health, engineDead)
    local rules = Config.Targets.npcs
    return {
        down = state[Config.NPCStatusKey] == 'down' or matches(state, rules.down.state)
            or (rules.down.healthAtOrBelow ~= false and health ~= nil and health <= rules.down.healthAtOrBelow),
        dead = engineDead == true or (health ~= nil and health <= 100), -- NPC health has a 100 baseline; never treat a corpse as normal.
    }
end

function EscortRules.allowed(status, npc)
    if npc then return status.down and not status.dead end
    return status.down or status.dead or status.carryable
end

function EscortRules.restrained(status)
    return status.down or status.dead or status.carryable
end

function EscortRules.distance(action)
    local distances = Config.Distances
    -- Support the user's current normalCarry / vehicleCarry names.
    local value = distances[action] or distances[action:sub(1, 4) == 'walk' and 'normalCarry' or 'vehicleCarry']
    assert(type(value) == 'number' and value > 0, 'Invalid escort distance: ' .. action)
    return value
end
