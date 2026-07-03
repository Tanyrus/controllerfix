--[[
    controllerfix - DirectInput backend.
    Detects DirectInput (and other) controllers via the Windows multimedia
    joystick API (winmm.dll), which exposes hardware IDs and names without COM.
    Copyright (C) 2026 Tanyrus <opensource@tinyresort.net>
    Licensed under the GNU General Public License v3 or later.
    See LICENSE for the full text; distributed WITHOUT ANY WARRANTY.
--]]

local ffi = require('ffi');

ffi.cdef[[
    typedef struct {
        uint16_t wMid;
        uint16_t wPid;
        char     szPname[32];
        uint32_t wXmin; uint32_t wXmax;
        uint32_t wYmin; uint32_t wYmax;
        uint32_t wZmin; uint32_t wZmax;
        uint32_t wNumButtons;
        uint32_t wPeriodMin; uint32_t wPeriodMax;
        uint32_t wRmin; uint32_t wRmax;
        uint32_t wUmin; uint32_t wUmax;
        uint32_t wVmin; uint32_t wVmax;
        uint32_t wCaps;
        uint32_t wMaxAxes;
        uint32_t wNumAxes;
        uint32_t wMaxButtons;
        char     szRegKey[32];
        char     szOEMVxD[260];
    } JOYCAPS;

    typedef struct {
        uint32_t dwSize;
        uint32_t dwFlags;
        uint32_t dwXpos;
        uint32_t dwYpos;
        uint32_t dwZpos;
        uint32_t dwRpos;
        uint32_t dwUpos;
        uint32_t dwVpos;
        uint32_t dwButtons;
        uint32_t dwButtonNumber;
        uint32_t dwPOV;
        uint32_t dwReserved1;
        uint32_t dwReserved2;
    } JOYINFOEX;

    uint32_t joyGetNumDevs(void);
    uint32_t joyGetDevCapsA(uint32_t uJoyID, JOYCAPS* pjc, uint32_t cbjc);
    uint32_t joyGetPosEx(uint32_t uJoyID, JOYINFOEX* pji);
]];

local JOYERR_NOERROR = 0;     -- call succeeded / device present
local JOY_RETURNALL  = 0xFF;  -- joyGetPosEx: request all axes/buttons

-- Guarded load: nil if winmm.dll is not present (non-Windows platforms).
local loaded, winmm = pcall(ffi.load, 'winmm');
local lib = loaded and winmm or nil;

local M = {};

-- Enumerate currently-connected WinMM joystick devices.
function M.enumerate()
    local devices = {};
    if lib == nil then
        return devices;
    end

    local info = ffi.new('JOYINFOEX');
    info.dwSize  = ffi.sizeof('JOYINFOEX');
    info.dwFlags = JOY_RETURNALL;
    local caps = ffi.new('JOYCAPS');

    local count = lib.joyGetNumDevs();
    for id = 0, count - 1 do
        if lib.joyGetPosEx(id, info) == JOYERR_NOERROR then
            local hwid, name = '0000:0000', 'Unknown device';
            if lib.joyGetDevCapsA(id, caps, ffi.sizeof('JOYCAPS')) == JOYERR_NOERROR then
                hwid = string.format('%04x:%04x', caps.wMid, caps.wPid);
                name = ffi.string(caps.szPname);
            end
            devices[#devices + 1] = {
                index = id,
                hwid  = hwid,
                name  = name,
            };
        end
    end
    return devices;
end

return M;
