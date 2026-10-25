-- AC8MissileBomb: weapon patch engine.
-- Carries the whole AC8SourceInit missile spec (375 scalar writes over 30
-- blueprints + 2 difficulty rows) into this mod, with two deliberate changes:
--   1. MSL `damage` is written as 90 (UGBL) instead of 80
--   2. MSL `ImpactRadius` 0 -> 18250 (UGBL blast radius, cm)
-- Everything else is applied verbatim from spec_weapons.lua.
-- Same guarantees as the original: preflight every row/field before the first
-- write, verify by read back, roll the whole set back on any failure.
local M = {}

local spec = require('spec_weapons')

local MSL_LIST = {
    'BP_plwp_msl_a0',
    'BP_plwp_msl_a1',
    'BP_plwp_msl_f0',
    'BP_plwp_msl_j0',
    'BP_plwp_msl_r0',
}

local MSL_ROWS = {
    ['BP_plwp_msl_a0'] = true,
    ['BP_plwp_msl_a1'] = true,
    ['BP_plwp_msl_f0'] = true,
    ['BP_plwp_msl_j0'] = true,
    ['BP_plwp_msl_r0'] = true,
}

-- Vanilla MSL damage (measured on build 25201480 with no other weapon mod).
local VANILLA_DAMAGE = 40

local cfg = nil
pcall(function() cfg = require('config') end)

function M.variant()
    if cfg ~= nil and type(cfg.variant) == 'string' then return cfg.variant end
    return 'enhanced'
end

local DAMAGE_AFTER = 90        -- UGBL direct damage (vanilla MSL is 40)
local IMPACT_RADIUS = 18250    -- UGBL blast radius in cm (~182 m)

-- Explosion visual. Measured on both weapons: the missile carries the small
-- air-explosion effect while UGBL carries the large one.
--   MSL : NS_airExplosionA_S      (_S = small)
--   UGBL: NS_airExplosion_L001    (_L = large)
-- The reference lives on the weapon's WeaponCollisionEffectModule subobject.
-- The asset is taken as a live reference from the bomb's CDO instead of being
-- loaded from a path string: LoadAsset rejected the path form that GetFullName
-- prints, and a hard reference cannot be misspelled.
local BOMB_CDO_PATH = '/Game/Blueprints/Weapons/BOMB/UGB/Player/UgbL/BP_plwp_ugbl_r0'
local BOMB_CDO_LEAF = 'BP_plwp_ugbl_r0'
local VFX_MODULE = 'CollisionEffectModule'
local VFX_SOURCE_FIELD = 'OnAirExplosionParticles_Niagara'
local VFX_OBJECT_FIELDS = {
    'OnAirExplosionParticles_Niagara',
    'OnCollisionParticlesDestroyedTarget_Niagara',
}
local VFX_BP_FIELD = 'OnBuildingCollisionParticleNoTouch_Niagara'

-- Cached MSL CDO from the last successful apply. The drift check reads it
-- directly instead of calling resolve(), because resolving means LoadAsset on
-- 30 blueprints and that appears to make the game re-load and reset the CDOs
-- (which is exactly what the drift check would then report).
local cached_sample = nil

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) == 'number' then
        return math.abs(a - b) <= math.max(1e-5, math.max(math.abs(a), math.abs(b)) * 1e-7)
    end
    return a == b
end

local function fullpath(o)
    local ok, n = pcall(function() return o:GetFullName() end)
    if ok and type(n) == 'string' then return (n:match('^%S+ (.+)$')) or n end
end

-- Builds the patch list.
--   enhanced: the full ported spec, with MSL damage set to UGBL's value
--   normal:  only MSL damage + blast radius; every other stock value is left
--            untouched, so speed / homing / lock angles stay vanilla
function M.build_spec()
    local out = { overridden = 0, added = 0 }
    local variant = M.variant()

    if variant == 'normal' then
        for _, row in ipairs(MSL_LIST) do
            out[#out + 1] = { row = row, field = 'damage', before = VANILLA_DAMAGE, after = DAMAGE_AFTER }
            out[#out + 1] = { row = row, field = 'ImpactRadius', before = 0, after = IMPACT_RADIUS }
            out.overridden = out.overridden + 1
            out.added = out.added + 1
        end
        return out
    end

    for _, p in ipairs(spec.patches) do
        local after = p.after
        if p.field == 'damage' and MSL_ROWS[p.row] then
            after = DAMAGE_AFTER
            out.overridden = out.overridden + 1
        end
        out[#out + 1] = { row = p.row, field = p.field, before = p.before, after = after }
    end
    for row in pairs(MSL_ROWS) do
        out[#out + 1] = { row = row, field = 'ImpactRadius', before = 0, after = IMPACT_RADIUS }
        out.added = out.added + 1
    end
    return out
end

-- Resolves every profile to its class default object; difficulty rows come from
-- the settings DataTable, exactly like the original spec expected.
local function resolve()
    local objects = {}
    local canonical = {}

    for _, prof in ipairs(spec.profiles) do
        local ok, cls = pcall(function() return LoadAsset(prof.path) end)
        if not (ok and cls ~= nil and cls:IsValid() and cls:IsAnyClass()) then
            error('Source class unavailable: ' .. prof.row, 0)
        end
        canonical[prof.row] = fullpath(cls) or error('Missing canonical object path: ' .. prof.row, 0)
    end

    local okD, data = pcall(function() return LoadAsset(spec.tablePath) end)
    if not (okD and data ~= nil and data:IsValid()) then
        error('Player DataTable unavailable', 0)
    end

    for _, prof in ipairs(spec.profiles) do
        local ok, cls = pcall(function() return StaticFindObject(canonical[prof.row]) end)
        if not (ok and cls ~= nil and cls:IsValid()) then
            error('Canonical source lookup failed: ' .. canonical[prof.row], 0)
        end
        local okC, cdo = pcall(function() return cls:GetCDO() end)
        if not (okC and cdo ~= nil and cdo:IsValid()) then
            error('CDO unavailable: ' .. prof.row, 0)
        end
        objects[prof.row] = cdo
    end

    for _, name in ipairs({ 'C.STORY', 'EASY' }) do
        local ok, row = pcall(function() return data:FindRow(name) end)
        if not (ok and row ~= nil) then error('Missing difficulty row: ' .. name, 0) end
        objects['table:' .. name] = row
    end

    return objects
end

local function read_field(row, field)
    local ok, v = pcall(function() return row[field] end)
    if not ok then return nil, false end
    return v, true
end

local function object_name(o)
    if o == nil then return nil end
    local ok, n = pcall(function() return o:GetFullName() end)
    if ok and type(n) == 'string' then return n end
    return nil
end

local function same_object(a, b)
    if a == nil or b == nil then return false end
    local ok1, va = pcall(function() return a:IsValid() end)
    local ok2, vb = pcall(function() return b:IsValid() end)
    if not (ok1 and ok2 and va and vb) then return false end
    local okA, aa = pcall(function() return a:GetAddress() end)
    local okB, ab = pcall(function() return b:GetAddress() end)
    return okA and okB and aa == ab
end

-- The bomb's own CDO, used as the source of truth for the effect reference.
local cached_vfx = nil

local function bomb_cdo()
    for _, form in ipairs({
        BOMB_CDO_PATH .. '.' .. BOMB_CDO_LEAF .. '_C',
        BOMB_CDO_PATH .. '.' .. BOMB_CDO_LEAF,
        BOMB_CDO_PATH,
    }) do
        local ok, cls = pcall(function() return LoadAsset(form) end)
        if ok and cls ~= nil and cls:IsValid() then
            local okC, cdo = pcall(function() return cls:GetCDO() end)
            if okC and cdo ~= nil and cdo:IsValid() then return cdo end
        end
    end
end

-- Points the missile's explosion references at the bomb's large effect.
-- Returns changed, checked, errorText. Never throws.
local function apply_visuals(objects)
    local out = { changed = 0, checked = 0, err = nil }

    local bcdo = bomb_cdo()
    if bcdo == nil then
        out.err = 'bomb-cdo-unavailable'
        return out.changed, out.checked, out.err
    end
    local okM, bmod = pcall(function() return bcdo[VFX_MODULE] end)
    if not (okM and bmod ~= nil and bmod:IsValid()) then
        out.err = 'bomb-module-unavailable'
        return out.changed, out.checked, out.err
    end
    local okS, vfx = pcall(function() return bmod[VFX_SOURCE_FIELD] end)
    if not (okS and vfx ~= nil and vfx:IsValid()) then
        out.err = 'bomb-effect-reference-unavailable'
        return out.changed, out.checked, out.err
    end
    cached_vfx = vfx

    for row in pairs(MSL_ROWS) do
        local cdo = objects[row]
        if cdo ~= nil then
            local okMod, mod = pcall(function() return cdo[VFX_MODULE] end)
            if okMod and mod ~= nil and mod:IsValid() then
                for _, field in ipairs(VFX_OBJECT_FIELDS) do
                    out.checked = out.checked + 1
                    local okC, current = pcall(function() return mod[field] end)
                    if okC and not same_object(current, vfx) then
                        local okW = pcall(function() mod[field] = vfx end)
                        local okR, after = pcall(function() return mod[field] end)
                        if okW and okR and same_object(after, vfx) then
                            out.changed = out.changed + 1
                        else
                            out.err = out.err or ('write-failed ' .. row .. '.' .. field)
                        end
                    end
                end
            end
            -- Blueprint-level effect used when the missile hits a building.
            out.checked = out.checked + 1
            local okC, current = pcall(function() return cdo[VFX_BP_FIELD] end)
            if okC and not same_object(current, vfx) then
                local okW = pcall(function() cdo[VFX_BP_FIELD] = vfx end)
                local okR, after = pcall(function() return cdo[VFX_BP_FIELD] end)
                if okW and okR and same_object(after, vfx) then
                    out.changed = out.changed + 1
                else
                    out.err = out.err or ('write-failed ' .. row .. '.' .. VFX_BP_FIELD)
                end
            end
        end
    end
    return out.changed, out.checked, out.err
end

-- Returns {ok=, written=, verified=, error=, rollbackErrors=}
function M.apply(log)
    local list = M.build_spec()
    local result = { ok = false, written = 0, verified = 0, overridden = list.overridden, added = list.added }

    local okRun, err = pcall(function()
        local objects = resolve()
        cached_sample = objects['BP_plwp_msl_a0']
        local ops = {}

        -- Preflight: every row/field must already hold its recorded before or
        -- after value. Unknown state aborts before the first write.
        for _, item in ipairs(list) do
            local row = objects[item.row]
            if row == nil then error('Missing row ' .. item.row, 0) end
            if type(item.before) ~= 'number' and type(item.before) ~= 'boolean' then
                error('Unsupported scalar specification ' .. item.row .. '.' .. item.field, 0)
            end
            if type(item.before) ~= type(item.after) then
                error('Type-changing specification ' .. item.row .. '.' .. item.field, 0)
            end
            local current, readable = read_field(row, item.field)
            if not readable or current == nil then
                error('Field unavailable ' .. item.row .. '.' .. item.field, 0)
            end
            if not (equal(current, item.before) or equal(current, item.after)) then
                error('Unexpected value ' .. item.row .. '.' .. item.field ..
                    ' current=' .. tostring(current) .. ' expected=' .. tostring(item.before) ..
                    '|' .. tostring(item.after) ..
                    ' (another weapon mod may already have changed this field)', 0)
            end
            if not equal(current, item.after) then
                ops[#ops + 1] = { row = item.row, field = item.field, before = current, after = item.after }
            end
            result.verified = result.verified + 1
        end

        -- Write phase with read back; any failure undoes everything attempted.
        local attempted = {}
        local okW, writeError = pcall(function()
            for _, op in ipairs(ops) do
                attempted[#attempted + 1] = op
                objects[op.row][op.field] = op.after
                local v = objects[op.row][op.field]
                if not equal(v, op.after) then
                    error('Readback mismatch ' .. op.row .. '.' .. op.field, 0)
                end
                result.written = result.written + 1
            end
        end)

        if not okW then
            local failures = 0
            for i = #attempted, 1, -1 do
                local op = attempted[i]
                local restored = pcall(function()
                    objects[op.row][op.field] = op.before
                end)
                if not restored then failures = failures + 1 end
            end
            error(tostring(writeError) .. ' (rolled back ' .. (#attempted - failures) .. '/' .. #attempted .. ')', 0)
        end

        -- Explosion visual: point MSL at the large bomb effect. This must not
        -- be able to fail the data patch, so it runs in its own pcall and only
        -- records a warning.
        local okV, vchanged, vchecked, vwhy = pcall(apply_visuals, objects)
        if okV then
            result.visuals = vchanged
            result.visualsChecked = vchecked
            result.visualsError = vwhy
        else
            result.visualsError = tostring(vchanged)
        end
    end)

    if not okRun then
        result.error = tostring(err)
        if log then log('WEAPONS FAILED ' .. result.error) end
        return result
    end

    result.ok = true
    if log then
        log('WEAPONS APPLIED verified=' .. result.verified .. ' written=' .. result.written ..
            ' overridden=' .. result.overridden .. ' added=' .. result.added ..
            ' vfx_changed=' .. tostring(result.visuals) .. '/' .. tostring(result.visualsChecked) ..
            (result.visualsError and (' vfx_warn=' .. tostring(result.visualsError)) or ''))
    end
    return result
end

-- Reports whether the MSL overrides and the large explosion reference are
-- still in place.
function M.check(log)
    local obj = cached_sample
    if obj == nil or not obj:IsValid() then
        if log then log('CHECK sample-unavailable') end
        return false
    end
    local ok, d, i = pcall(function() return obj['damage'], obj['ImpactRadius'] end)
    if not ok then
        if log then log('CHECK read-failed ' .. tostring(d)) end
        return false
    end
    local good = equal(d, DAMAGE_AFTER) and equal(i, IMPACT_RADIUS)

    local okM, mod = pcall(function() return obj[VFX_MODULE] end)
    if good and okM and mod ~= nil and mod:IsValid() then
        -- Prefer the cached reference: resolving the bomb CDO here would mean
        -- an extra LoadAsset on every drift check.
        local target = cached_vfx
        local okB = false
        if target ~= nil then
            local okv, v = pcall(function() return target:IsValid() end)
            okB = okv and v == true
        end
        if not okB then
            local bcdo = bomb_cdo()
            if bcdo ~= nil then
                local okBm, bmod = pcall(function() return bcdo[VFX_MODULE] end)
                if okBm and bmod ~= nil and bmod:IsValid() then
                    local okT, t = pcall(function() return bmod[VFX_SOURCE_FIELD] end)
                    if okT and t ~= nil then target = t; okB = true end
                end
            end
        end
        if okB then
            local okV, current = pcall(function() return mod[VFX_OBJECT_FIELDS[1]] end)
            if not (okV and same_object(current, target)) then
                good = false
                if log then log('CHECK drift vfx=' .. tostring(object_name(current))) end
            end
        end
    end

    if log and not good then
        log('CHECK drift damage=' .. tostring(d) .. ' impact=' .. tostring(i))
    end
    return good
end

return M
