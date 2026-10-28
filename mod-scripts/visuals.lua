-- AC8MissileBomb: stage 3 -- give the standard missile the UGBL bomb model.
-- Measured facts driving this file:
--   MSL a0 -> w_msl_a0 (2 materials), a1 -> w_qaam_a0 (3), r0/j0/f0 -> own (2)
--   UGBL   -> /Game/Vehicles/Weapons/w_ugbl_r0/Model/SM_w_ugbl_r0 (2 materials)
-- The missile's look comes from its StaticMesh component (and the second
-- HiddenMissileMesh component used for the rounds shown under the wing), so the
-- swap is the same SetStaticMesh + SetMaterial sequence the reference mods use.
-- Components with 3 material slots are reduced to the mesh's 2 slots.
local M = {}


local MESH_PATH = '/Game/Vehicles/Weapons/w_ugbl_r0/Model/SM_w_ugbl_r0.SM_w_ugbl_r0'
local MESH_NAME = 'SM_w_ugbl_r0'

local MSL_CLASSES = {
    'BP_plwp_msl_a0_C',
    'BP_plwp_msl_a1_C',
    'BP_plwp_msl_r0_C',
    'BP_plwp_msl_j0_C',
    'BP_plwp_msl_f0_C',
}

local MSL_PATHS = {
    '/Game/Blueprints/Weapons/MSL/Player/Msl/BP_plwp_msl_a0',
    '/Game/Blueprints/Weapons/MSL/Player/Msl/BP_plwp_msl_a1',
    '/Game/Blueprints/Weapons/MSL/Player/Msl/BP_plwp_msl_r0',
    '/Game/Blueprints/Weapons/MSL/Player/Msl/BP_plwp_msl_j0',
    '/Game/Blueprints/Weapons/MSL/Player/Msl/BP_plwp_msl_f0',
}

-- v1.1: cover every MSL blueprint variant, not only the five measured first.
-- Different aircraft can use a different MSL visual variant (user reports:
-- F/A-18C and Mirage 2000-5 changed, Su-33 / Su-47 did not), so after the known
-- list we probe a set of extra suffixes once per session and patch whatever
-- loads, and instance matching is done on the class name instead of a fixed list.
local EXTRA_SUFFIXES = {
    'a1', 'b0', 'b1', 'c0', 'c1', 'c2', 'd0', 'd1', 'e0', 'e1', 'g0', 'g1',
    'h0', 'h1', 'i0', 'i1', 'k0', 'k1', 'l0', 'l1', 'm0', 'm1', 'n0', 'n1',
    'o0', 'o1', 'p0', 'p1', 'q0', 'q1', 'r1', 'r2', 's0', 's1', 't0', 't1',
    'u0', 'u1', 'v0', 'v1', 'w0', 'w1', 'x0', 'x1', 'y0', 'y1', 'z0', 'z1',
    '00', '01', '02', '03', '04', '05', '06', '07', '08', '09',
}

local extra_tried = false
local extra_classes = {}

local function is_msl_leaf(leaf)
    if type(leaf) ~= 'string' then return false end
    return leaf:lower():find('msl', 1, true) ~= nil
end

-- Components that carry the visible missile body. The third name is used by
-- some variants; reading a property that does not exist simply fails.
local COMPONENT_FIELDS = { 'StaticMesh', 'HiddenMissileMesh', 'MissileMesh' }

local function valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end

local function name_of(o)
    if not valid(o) then return nil end
    local ok, n = pcall(function() return o:GetFullName() end)
    if ok and type(n) == 'string' then return n end
    return nil
end

local function leaf_of(s) return (tostring(s):match('([^/%.]+)$')) end

local function load_class(path)
    local leaf = leaf_of(path)
    for _, form in ipairs({ path .. '.' .. leaf .. '_C', path .. '.' .. leaf, path }) do
        local ok, v = pcall(function() return LoadAsset(form) end)
        if ok and valid(v) then return v end
    end
end

local function is_bomb(comp)
    local ok, m = pcall(function() return comp.StaticMesh end)
    if not (ok and valid(m)) then return false end
    local n = name_of(m)
    return n ~= nil and n:find(MESH_NAME, 1, true) ~= nil
end

-- Swaps one StaticMeshComponent to the bomb mesh and aligns its materials.
-- Returns true when it actually changed something.
local function swap_component(comp, mesh)
    if not valid(comp) then return false end
    if is_bomb(comp) then return false end

    -- Material list straight off the static mesh asset (same approach as the
    -- reference mods: mesh.StaticMaterials[i].MaterialInterface).
    local okArr, mats = pcall(function() return mesh.StaticMaterials end)
    if not (okArr and mats ~= nil) then return false end
    local okCnt, matCount = pcall(function() return #mats end)
    if not (okCnt and type(matCount) == 'number' and matCount >= 1) then return false end

    local newMats = {}
    for i = 1, matCount do
        local okM, mat = pcall(function() return mats[i].MaterialInterface end)
        newMats[i] = (okM and valid(mat)) and mat or nil
    end

    local okOld, oldCount = pcall(function() return comp:GetNumMaterials() end)

    local okSet = pcall(function() comp:SetStaticMesh(mesh) end)
    local okRead, after = pcall(function() return comp.StaticMesh end)
    if not (okSet and okRead and valid(after)) then return false end
    if not tostring(name_of(after)):find(MESH_NAME, 1, true) then return false end

    -- Fill what the mesh provides, never exceed the component's own slots.
    if okOld and type(oldCount) == 'number' then
        for i = 1, math.min(matCount, oldCount) do
            if newMats[i] ~= nil then
                pcall(function() comp:SetMaterial(i - 1, newMats[i]) end)
            end
        end
    end
    return true
end

local cached_mesh = nil

-- Take the bomb mesh straight from the bomb blueprint's own component: a live
-- reference cannot be misspelled, and LoadAsset rejected a path form earlier.
local BOMB_CDO_PATH = '/Game/Blueprints/Weapons/BOMB/UGB/Player/UgbL/BP_plwp_ugbl_r0'
local BOMB_CDO_LEAF = 'BP_plwp_ugbl_r0'

local function bomb_cdo()
    for _, form in ipairs({
        BOMB_CDO_PATH .. '.' .. BOMB_CDO_LEAF .. '_C',
        BOMB_CDO_PATH .. '.' .. BOMB_CDO_LEAF,
        BOMB_CDO_PATH,
    }) do
        local ok, cls = pcall(function() return LoadAsset(form) end)
        if ok and valid(cls) then
            local okC, cdo = pcall(function() return cls:GetCDO() end)
            if okC and valid(cdo) then return cdo end
        end
    end
end

local function bomb_mesh()
    local cdo = bomb_cdo()
    if not valid(cdo) then return nil end
    local okComp, comp = pcall(function() return cdo['StaticMesh'] end)
    if not (okComp and valid(comp)) then return nil end
    local okM, m = pcall(function() return comp['StaticMesh'] end)
    if okM and valid(m) then return m end
    return nil
end

local function get_mesh()
    if valid(cached_mesh) then return cached_mesh end
    local m = bomb_mesh()
    if valid(m) then cached_mesh = m; return m end
    local ok, a = pcall(function() return LoadAsset(MESH_PATH) end)
    if ok and valid(a) then cached_mesh = a; return a end
    return nil
end

-- Explosion effect swapping is DISABLED by default.
-- Evidence (schema dump 2026-10-24): MSL and UGBL have byte-identical struct
-- schemas -- SeaExplosionInfo{duration,Radius}, SWDRHitParam{ExplosionRadiusMeter,
-- MissileRaidusMeter}, no asset references anywhere. Their ObjectProperty sets
-- differ only in the collision module's Niagara, and rewriting it produced no
-- visible change. So the explosion visual is chosen in native code, not by any
-- writable property. Keep this off; do not re-enable without new evidence.
local EFFECT_ENABLED = false

-- Explosion effect reference, taken from the bomb's own collision effect module.
local VFX_MODULE = 'CollisionEffectModule'
local VFX_SOURCE_FIELD = 'OnAirExplosionParticles_Niagara'
local VFX_FIELDS = {
    'OnAirExplosionParticles_Niagara',
    'OnCollisionParticlesDestroyedTarget_Niagara',
}
local VFX_BP_FIELD = 'OnBuildingCollisionParticleNoTouch_Niagara'
local cached_vfx = nil

local function bomb_effect()
    if valid(cached_vfx) then return cached_vfx end
    local cdo = bomb_cdo()
    if not valid(cdo) then return nil end
    local okMod, mod = pcall(function() return cdo[VFX_MODULE] end)
    if not (okMod and valid(mod)) then return nil end
    local okV, vfx = pcall(function() return mod[VFX_SOURCE_FIELD] end)
    if okV and valid(vfx) then cached_vfx = vfx; return vfx end
    return nil
end

local function same_object(a, b)
    if not (valid(a) and valid(b)) then return false end
    local okA, aa = pcall(function() return a:GetAddress() end)
    local okB, ab = pcall(function() return b:GetAddress() end)
    return okA and okB and aa == ab
end

-- Writes the bomb's explosion references onto one owner (CDO or live actor).
-- Instances matter: pooled missiles copy the module when they are constructed,
-- which can happen before the blueprint defaults are patched.
function M.apply_effect(owner)
    if not EFFECT_ENABLED then return 0 end
    local vfx = bomb_effect()
    if not vfx then return 0 end
    local changed = 0
    local okMod, mod = pcall(function() return owner[VFX_MODULE] end)
    if okMod and valid(mod) then
        for _, field in ipairs(VFX_FIELDS) do
            local okC, current = pcall(function() return mod[field] end)
            if okC and not same_object(current, vfx) then
                local okW = pcall(function() mod[field] = vfx end)
                local okR, after = pcall(function() return mod[field] end)
                if okW and okR and same_object(after, vfx) then changed = changed + 1 end
            end
        end
    end
    local okB, current = pcall(function() return owner[VFX_BP_FIELD] end)
    if okB and not same_object(current, vfx) then
        local okW = pcall(function() owner[VFX_BP_FIELD] = vfx end)
        local okR, after = pcall(function() return owner[VFX_BP_FIELD] end)
        if okW and okR and same_object(after, vfx) then changed = changed + 1 end
    end
    return changed
end

-- Applies the swap to a weapon actor (or to a class default object).
local function swap_owner(owner, mesh)
    local changed = 0
    for _, field in ipairs(COMPONENT_FIELDS) do
        local ok, comp = pcall(function() return owner[field] end)
        if ok and valid(comp) then
            if swap_component(comp, mesh) then changed = changed + 1 end
        end
    end
    return changed
end

-- Template pass: change the blueprint defaults so freshly spawned missiles are
-- already bombs (this also covers object-pool reuse of pre-built actors).
function M.apply_cdo(log)
    local mesh = get_mesh()
    if not mesh then
        if log then log('VISUALS mesh-unavailable ' .. MESH_PATH) end
        return 0, 0
    end
    local changed, checked = 0, 0

    local function patch_class(cls)
        if not valid(cls) then return end
        local ok, cdo = pcall(function() return cls:GetCDO() end)
        local obj = (ok and valid(cdo)) and cdo or cls
        checked = checked + 1
        changed = changed + swap_owner(obj, mesh)
        local okE, ce = pcall(M.apply_effect, obj)
        if okE then changed = changed + (ce or 0) end
    end

    for _, path in ipairs(MSL_PATHS) do
        local cls = load_class(path)
        if cls then patch_class(cls) end
    end

    -- One-off probe: other MSL visual variants used by other aircraft.
    if not extra_tried then
        extra_tried = true
        for _, sfx in ipairs(EXTRA_SUFFIXES) do
            local cls = load_class('/Game/Blueprints/Weapons/MSL/Player/Msl/BP_plwp_msl_' .. sfx)
            if cls then extra_classes[#extra_classes + 1] = cls end
        end
        if log then log('VISUALS extra-variants found=' .. tostring(#extra_classes)) end
    end
    for _, cls in ipairs(extra_classes) do patch_class(cls) end

    if log and changed > 0 then
        log('VISUALS cdo changed=' .. changed .. ' classes=' .. checked
            .. ' extra=' .. tostring(#extra_classes))
    end
    return changed, checked
end

-- Instance pass: catch missiles that spawn at runtime. BeginPlay fires for
-- pooled actors once, so the template pass above stays the main mechanism.
local hooksInstalled = false
local actorLogs = 0

function M.install_hooks(log)
    if hooksInstalled then return end
    hooksInstalled = true
    if type(RegisterBeginPlayPostHook) ~= 'function' then
        if log then log('VISUALS hook-unavailable') end
        return
    end
    -- One missile actor: mesh + explosion references, both on the instance.
    local function on_actor(actor)
        if not valid(actor) then return end
        local full = name_of(actor)
        if not full then return end
        local leaf = leaf_of(full)
        if not is_msl_leaf(leaf) then return end
        local mesh = get_mesh()
        local changed = 0
        if mesh then
            local okS, n = pcall(swap_owner, actor, mesh)
            if okS and type(n) == 'number' then changed = n end
        end
        local okE, ce = pcall(M.apply_effect, actor)
        if actorLogs < 8 then
            actorLogs = actorLogs + 1
            if log then
                log('VISUALS actor ' .. leaf .. ' changed=' .. tostring(changed)
                    .. ' effect_changed=' .. tostring(okE and ce or 'ERR'))
            end
        end
    end

    pcall(RegisterBeginPlayPostHook, function(param)
        local ok, actor = pcall(function() return param:get() end)
        if ok then on_actor(actor) end
    end)

    -- Weapon creation path used by this build; covers actors that never go
    -- through BeginPlay again because they come from the object pool.
    for _, event in ipairs({ 'OnInitialized', 'OnCreateWeapon_BP' }) do
        local ok = pcall(function()
            RegisterHook('/Script/Live.LiveWeaponBase:' .. event, function() end, function(param)
                local okA, actor = pcall(function() return param:get() end)
                if okA then on_actor(actor) end
            end)
        end)
        if log then log('VISUALS hook ' .. event .. '=' .. tostring(ok)) end
    end

    -- Fire path: re-assert right before the salvo leaves the rails.
    pcall(function()
        RegisterHook('/Script/Live.LivePlayerWeaponActivator:MainWeaponPressed', function() end, function()
            pcall(M.sweep)
        end)
    end)

    if log then log('VISUALS hooks installed (any MSL variant, known=' .. #MSL_CLASSES .. ')') end
end

-- Used by the drift check: is the template still the bomb?
-- Sweep the local player's live weapon arrays and re-assert mesh + effect.
-- Missiles are pooled and the game reloads blueprints between missions, so the
-- references can be reset after a weapon was already patched; re-asserting on
-- the instances themselves is what makes it stick.
function M.sweep(log)
    if type(FindFirstOf) ~= 'function' then return 0 end
    local okpc, pcw = pcall(function() return FindFirstOf('PlayerController') end)
    if not okpc or pcw == nil then return 0 end
    local okPc, pc = pcall(function() return pcw:get() end)
    if not (okPc and valid(pc)) then return 0 end
    local okPawn, pawn = pcall(function() return pc.Pawn end)
    if not (okPawn and valid(pawn)) then return 0 end
    local okAct, act = pcall(function() return pawn.PlayerWeaponActivator end)
    if not (okAct and valid(act)) then return 0 end

    local changed = 0
    for _, field in ipairs({ 'SpawnedWeapons', 'ActiveWeapons' }) do
        local okArr, arr = pcall(function() return act[field] end)
        if okArr and arr ~= nil then
            local okN, n = pcall(function() return #arr end)
            if okN and type(n) == 'number' and n > 0 and n <= 512 then
                for i = 1, n do
                    local okW, w = pcall(function() return arr[i] end)
                    if okW and valid(w) then
                        local leaf = leaf_of(name_of(w) or '')
                        if is_msl_leaf(leaf) then
                            local mesh = get_mesh()
                            if mesh then pcall(swap_owner, w, mesh) end
                            local okE, ce = pcall(M.apply_effect, w)
                            if okE then changed = changed + (ce or 0) end
                        end
                    end
                end
            end
        end
    end
    if log and changed > 0 then log('VISUALS sweep changed=' .. changed) end
    return changed
end

function M.is_applied(log)
    local cls = load_class(MSL_PATHS[1])
    if not cls then return false end
    local ok, cdo = pcall(function() return cls:GetCDO() end)
    local obj = (ok and valid(cdo)) and cdo or cls
    local okC, comp = pcall(function() return obj['StaticMesh'] end)
    if not (okC and valid(comp)) then return false end
    return is_bomb(comp)
end

return M
