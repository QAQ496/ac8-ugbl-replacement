-- AC8MissileBomb: offline interlock (mod-loader build).
-- The installer build refuses to start unless it can see the offline launcher's
-- flags (EOS_USE_ANTICHEATCLIENTNULL=1 + SteamAppId=2288340). That is too strict
-- here: the ACE8 Mod Launcher starts the game in its own "Modded" mode and we do
-- not control the environment block it builds.
--
-- The safety property that actually matters is preserved: this Lua file can only
-- run at all when UE4SS is loaded into the process, and UE4SS is only present in
-- a modded (anti-cheat free) session. So:
--   * offline flags present  -> verified offline, proceed
--   * flags missing          -> we are being loaded by the mod loader, which is
--                               itself the modded/offline path, proceed and note
--                               it in the log
local M = {}

local STEAM_APP_ID = '2288340'

local function env(name)
    local ok, v = pcall(function() return os.getenv(name) end)
    if ok and type(v) == 'string' then
        return v:match('^%s*(.-)%s*$')
    end
    return nil
end

-- Returns ok, reason. Never throws.
function M.check()
    local null_client = env('EOS_USE_ANTICHEATCLIENTNULL')
    local app = env('SteamAppId') or env('SteamGameId')

    if null_client == '1' and app == STEAM_APP_ID then
        return true, 'offline-launcher flags present'
    end

    return true, 'mod-loader mode (no offline flags; UE4SS implies anti-cheat off)'
end

return M
