--[[
    controllerfix - Automatically manages the FFXI gamepad setting to match
    controller presence (XInput and DirectInput) and prevent input stutter.

    Copyright (C) 2026 Tanyrus <opensource@tinyresort.net>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name    = 'controllerfix';
addon.author  = 'Tanyrus';
addon.version = '1.0.0';
addon.desc    = 'Auto-manages the disable enumeration gamepad setting based on controller presence (XInput + DirectInput) to resolve the game stuttering when controller is turned off.';

require('common');
local chat = require('chat');

-- ------------------------------------------------------------------
-- Chat output helper
-- ------------------------------------------------------------------
local function notify(text)
    print(chat.header(addon.name):append(chat.message(text)));
end

-- ------------------------------------------------------------------
-- Detection backends
-- ------------------------------------------------------------------
local xinput      = require('xinput');
local directinput = require('directinput');

-- ------------------------------------------------------------------
-- Persisted settings: the device blacklist (set of hwid strings).
-- ------------------------------------------------------------------
local settings = require('settings');

local default_settings = T{
    blacklist = T{},  -- ['045e:028e'] = true
};

local config = settings.load(default_settings);

settings.register('settings', 'settings_update', function (updated)
    if updated ~= nil then
        config = updated;
    end
end);

-- ------------------------------------------------------------------
-- Detection glue
-- ------------------------------------------------------------------

-- Combine both backends and apply the blacklist.
local function survey()
    local devices = T{};
    local winmm_active = 0;
    for _, d in ipairs(directinput.enumerate()) do
        d.blacklisted = config.blacklist[d.hwid] == true;
        devices:append(d);
        if not d.blacklisted then
            winmm_active = winmm_active + 1;
        end
    end

    local xin = xinput.count();

    return {
        devices = devices,
        present = (xin > 0) or (winmm_active > 0),
        xinput  = xin > 0,
        dinput  = winmm_active > xin,  -- WinMM sees a non-blacklisted pad XInput doesn't
    };
end

-- Type descriptor for the detected controller(s), e.g. 'XInput', 'XInput + DirectInput'.
-- Only meaningful when s.present is true (at least one flag is then set).
local function type_label(s)
    local parts = T{};
    if s.xinput then parts:append('XInput'); end
    if s.dinput then parts:append('DirectInput'); end
    return table.concat(parts, ' + ');
end

-- Human-readable presence label for status output.
local function presence_label(s)
    if not s.present then
        return 'Not Connected';
    end
    return 'Connected (' .. type_label(s) .. ')';
end

-- ------------------------------------------------------------------
-- Gamepad state control
-- ------------------------------------------------------------------
local POLL_INTERVAL = 3.0;  -- seconds between polls

local state = T{
    last_disabled = nil,   -- last observed GetDisableGamepad() value
    last_check    = 0,     -- os.clock() of last poll
};

-- Guarded lookup: nil while AshitaCore is not ready yet.
local function get_input_manager()
    local ok, mgr = pcall(function ()
        return AshitaCore:GetInputManager();
    end);
    return ok and mgr or nil;
end

-- Reconcile the game's gamepad flag with real controller presence.
local function apply()
    local mgr = get_input_manager();
    if mgr == nil then
        return;
    end

    local s = survey();
    local disabled = mgr:GetDisableGamepad();
    local we_changed = false;

    if s.present and disabled then
        mgr:SetDisableGamepad(false);
        disabled = false;
        we_changed = true;
        notify(string.format('Controller Detected (%s): Enabling Gamepad Enumeration', type_label(s)));
    elseif (not s.present) and (not disabled) then
        mgr:SetDisableGamepad(true);
        disabled = true;
        we_changed = true;
        notify('No Controller Detected: Disabling Gamepad Enumeration');
    end

    -- Announce external (manual) toggles we did not perform.
    if state.last_disabled ~= nil and disabled ~= state.last_disabled and not we_changed then
        notify(disabled and 'Gamepad input turned off externally.' or 'Gamepad input turned on externally.');
    end

    state.last_disabled = disabled;
end

-- ------------------------------------------------------------------
-- Commands
-- ------------------------------------------------------------------
local function cmd_status()
    notify('Current status:');
    local mgr = get_input_manager();
    if mgr ~= nil then
        local disabled = mgr:GetDisableGamepad();
        print(chat.header(addon.name)
            :append(chat.message('  Gamepad input: '))
            :append(chat.success(disabled and 'Disabled' or 'Enabled')));
    end
    local s = survey();
    print(chat.header(addon.name)
        :append(chat.message('  Controllers: '))
        :append(chat.success(presence_label(s))));
end

local function cmd_list()
    local s = survey();
    notify('Detected devices:');
    if #s.devices == 0 then
        notify('  (none)');
        return;
    end
    for _, d in ipairs(s.devices) do
        local flag = d.blacklisted and '[blacklisted]' or 'counted';
        notify(string.format('  %d  %s  %-24s  %s', d.index, d.hwid, d.name, flag));
    end
end

-- Resolve a user token (a list index or a hwid) to a lowercase hwid.
local function resolve_hwid(token)
    local idx = tonumber(token);
    if idx ~= nil then
        for _, d in ipairs(directinput.enumerate()) do
            if d.index == idx then
                return d.hwid;
            end
        end
        return nil, string.format('No detected device with index %d. Run /controllerfix list.', idx);
    end
    if token:match('^%x%x%x%x:%x%x%x%x$') then
        return token:lower();
    end
    return nil, string.format('"%s" is not a valid index or hwid (expected e.g. 045e:028e).', token);
end

local function cmd_blacklist(args)
    local action = args[3] and args[3]:lower() or nil;

    if action == nil then
        notify('Blacklist:');
        local any = false;
        for hwid in pairs(config.blacklist) do
            any = true;
            notify('  ' .. hwid);
        end
        if not any then
            notify('  (empty)');
        end
        return;
    end

    local token = args[4];
    if (action ~= 'add' and action ~= 'remove') or token == nil then
        notify('Usage: /controllerfix blacklist [add|remove] <index|hwid>');
        return;
    end

    local hwid, err = resolve_hwid(token);
    if hwid == nil then
        notify(err);
        return;
    end

    if action == 'add' then
        config.blacklist[hwid] = true;
        settings.save();
        notify(string.format('Blacklisted %s. It no longer counts as a controller.', hwid));
    else
        if config.blacklist[hwid] == nil then
            notify(string.format('%s is not in the blacklist.', hwid));
            return;
        end
        config.blacklist[hwid] = nil;
        settings.save();
        notify(string.format('Removed %s from the blacklist.', hwid));
    end
end

-- ------------------------------------------------------------------
-- Events
-- ------------------------------------------------------------------
ashita.events.register('load', 'load_cb', function ()
    local mgr = get_input_manager();
    if mgr ~= nil then
        state.last_disabled = mgr:GetDisableGamepad();
    end
    notify('Loaded. Monitoring controller presence (XInput + DirectInput).');
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    local now = os.clock();
    if (now - state.last_check) >= POLL_INTERVAL then
        state.last_check = now;
        apply();
    end
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if #args == 0 or args[1]:lower() ~= '/controllerfix' then
        return;
    end
    e.blocked = true;

    local sub = (#args >= 2) and args[2]:lower() or '';
    if sub == 'list' then
        cmd_list();
    elseif sub == 'blacklist' then
        cmd_blacklist(args);
    else
        cmd_status();
    end
end);
