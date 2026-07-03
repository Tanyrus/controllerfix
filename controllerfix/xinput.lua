--[[
    controllerfix - XInput backend.
    Copyright (C) 2026 Tanyrus <opensource@tinyresort.net>
    Licensed under the GNU General Public License v3 or later.
    See LICENSE for the full text; distributed WITHOUT ANY WARRANTY.
--]]

local ffi = require('ffi');

ffi.cdef[[
    typedef struct {
        uint32_t dwPacketNumber;
        uint16_t wButtons;
        uint8_t  bLeftTrigger;
        uint8_t  bRightTrigger;
        int16_t  sThumbLX;
        int16_t  sThumbLY;
        int16_t  sThumbRX;
        int16_t  sThumbRY;
    } XINPUT_STATE;

    uint32_t XInputGetState(uint32_t dwUserIndex, XINPUT_STATE* pState);
]];

local ERROR_SUCCESS   = 0;  -- XInputGetState: controller connected
local XUSER_MAX_COUNT = 4;  -- XInput supports pad indices 0..3

-- Guarded load: try each DLL name; nil if none are present.
local function load_first(...)
    for _, name in ipairs({...}) do
        local ok, lib = pcall(ffi.load, name);
        if ok and lib ~= nil then
            return lib;
        end
    end
    return nil;
end

local lib = load_first('xinput1_4', 'xinput1_3', 'xinput9_1_0');

local M = {};

-- Count connected XInput pads (indices 0..3).
function M.count()
    if lib == nil then
        return 0;
    end
    local state = ffi.new('XINPUT_STATE');
    local n = 0;
    for i = 0, XUSER_MAX_COUNT - 1 do
        if lib.XInputGetState(i, state) == ERROR_SUCCESS then
            n = n + 1;
        end
    end
    return n;
end

return M;
