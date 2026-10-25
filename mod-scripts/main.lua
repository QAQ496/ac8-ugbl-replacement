-- AC8MissileBomb -- entry point (stage 1: weapon spec port).
-- Flow: offline interlock -> optional read-only probe -> apply weapon spec.
-- The spec is re-applied at every mission start (idempotent), matching how the
-- original missile module behaved.
local guard = require('offline_guard')
local cfg = require('config')

-- A broken optional module must never take the data patch down with it.
local okProbe, probe = pcall(require, 'probe')
if not okProbe then probe = nil end
local okWeapons, weapons = pcall(require, 'weapons')
if not okWeapons then weapons = nil end
local okVisuals, visuals = pcall(require, 'visuals')
if not okVisuals then visuals = nil end

local applying = false
local disabled = false
local attempts = 0
local sweepInstalled = false
local MAX_ATTEMPTS = 4

local function log(msg) print('[AC8MB] ' .. tostring(msg) .. '\n') end

local function applyAt(reason)
    if applying or disabled or weapons == nil then return end
    applying = true
    attempts = attempts + 1
    local ok, res = pcall(weapons.apply, log)
    applying = false
    if not ok then
        log('WEAPONS ERROR (' .. tostring(reason) .. ') ' .. tostring(res))
        if attempts >= MAX_ATTEMPTS then disabled = true end
        return
    end
    if not res.ok then
        -- weapons.apply already logged the reason; retry on the next trigger
        -- (a too-early apply is expected to fail once), then give up.
        if attempts >= MAX_ATTEMPTS then disabled = true end
        return
    end
    log('WEAPONS reason=' .. tostring(reason) .. ' attempt=' .. attempts)
    attempts = 0
    if cfg.apply_visuals and visuals ~= nil then
        local okV, cv = pcall(visuals.apply_cdo, log)
        if okV then log('VISUALS stage=' .. tostring(reason) .. ' changed=' .. tostring(cv)) end
        -- Re-assert on live weapon instances: pooled missiles can carry stale
        -- references even after the blueprint defaults are patched.
        if cfg.sweep_visuals and type(LoopInGameThreadAfterFrames) == 'function' and not sweepInstalled then
            sweepInstalled = true
            local sweepLogs = 0
            pcall(LoopInGameThreadAfterFrames, 240, function()
                if visuals == nil then return end
                local okS, changed = pcall(visuals.sweep)
                if okS and type(changed) == 'number' and changed > 0 and sweepLogs < 5 then
                    sweepLogs = sweepLogs + 1
                    log('VISUALS sweep repaired=' .. changed)
                end
            end)
        end
    end
end

local okg, reason = guard.check()
if not okg then log('DISABLED ' .. tostring(reason)); return end
log('guard=offline-ok stage=1')
if not okWeapons then log('WARN weapons module failed to load: ' .. tostring(weapons)) end
if not okVisuals then log('WARN visuals module failed to load: ' .. tostring(visuals)) end
if cfg.apply_visuals and visuals ~= nil then pcall(visuals.install_hooks, log) end

if cfg.probe_vfx then
    local okP, vfxProbe = pcall(require, 'vfx_probe')
    if okP and vfxProbe ~= nil then
        pcall(vfxProbe.install, log)
    else
        log('WARN vfx_probe failed to load: ' .. tostring(vfxProbe))
    end
end

if cfg.probe and probe ~= nil then
    if type(ExecuteInGameThreadAfterFrames) == 'function' then
        pcall(ExecuteInGameThreadAfterFrames, 900, function()
            local ok, err = pcall(probe.run, log)
            if not ok then log('PROBE error ' .. tostring(err)) end
        end)
    end
end

if cfg.apply_weapons then
    -- Mission initialization is the reliable moment; the blueprint CDOs are
    -- already loaded and any earlier modification is visible.
    if type(RegisterInitGameStatePreHook) == 'function' then
        pcall(RegisterInitGameStatePreHook, function(context)
            local ok, name = pcall(function()
                local mode = context:get()
                if mode and mode:IsValid() then return mode:GetFullName() end
            end)
            if ok and type(name) == 'string' and name:find('/Game/Maps/Ingame/', 1, true) then
                applyAt('mission-initialize')
            end
        end)
    end
    if type(ExecuteInGameThreadAfterFrames) == 'function' then
        pcall(ExecuteInGameThreadAfterFrames, 30, function() applyAt('engine-ready') end)
    else
        applyAt('module-load')
    end

    -- Drift check: the game can reload a blueprint and reset its CDO, which
    -- silently reverts the overrides. Re-apply when the known values are gone.
    local checks = 0
    local function drift()
        if disabled or applying then return end
        checks = checks + 1
        if checks > 40 then return end
        local okC, good = pcall(weapons.check)
        if okC and not good then
            log('DRIFT detected, re-applying')
            applyAt('drift-repair')
        end
    end
    if cfg.drift_check and type(LoopInGameThreadAfterFrames) == 'function' then
        pcall(LoopInGameThreadAfterFrames, 900, drift)
    end
end


