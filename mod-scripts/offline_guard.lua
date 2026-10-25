-- AC8MissileBomb: offline interlock.
-- The mod is strictly single-player. It refuses to initialize unless the
-- process was started by an offline launcher that keeps EAC out of the
-- session (no start_protected_game.exe) and nulls the EOS anti-cheat client.
local M = {}

local STEAM_APP_ID = '2288340'

local function env(name)
    local ok, v = pcall(function() return os.getenv(name) end)
    if ok and type(v) == 'string' then
        local t = v:match('^%s*(.-)%s*$')
        return t
    end
    return nil
end

-- Returns ok, reason. Never throws.
function M.check()
    local null_client = env('EOS_USE_ANTICHEATCLIENTNULL')
    if null_client ~= '1' then
        return false, 'offline interlock: EOS_USE_ANTICHEATCLIENTNULL is not 1 (launch through the offline launcher)'
    end
    local app = env('SteamAppId') or env('SteamGameId')
    if app ~= STEAM_APP_ID then
        return false, 'offline interlock: SteamAppId is not ' .. STEAM_APP_ID .. ' (launch through the offline launcher)'
    end
    return true
end

return M
