# controllerfix

An [Ashita](https://www.ashitaxi.com/) addon for Final Fantasy XI that turns the
game's gamepad setting off when no controller is connected and back on when one
appears. This avoids the input stutter FFXI has when gamepad input is enabled but
no controller is plugged in.

It checks for controllers every few seconds and detects both **XInput** (Xbox and
most modern pads) and **DirectInput** devices. If something is wrongly detected as
a controller (my Alice Duo keyboard is), you can blacklist it.

## Installation

1. Copy the `controllerfix` folder into your Ashita `Game/addons/` directory.
2. Load it with `/addon load controllerfix`, or add that to your default script to
   load it at every launch.

## Commands

- `/controllerfix` (or `/controllerfix status`) — show gamepad and controller status.
- `/controllerfix list` — list detected devices as `index  hwid  name  state`.
- `/controllerfix blacklist` — show the current blacklist.
- `/controllerfix blacklist add <index|hwid>` — stop counting a device as a controller.
- `/controllerfix blacklist remove <index|hwid>` — count it again.

For `add` and `remove` you can pass the index shown by `list`. Entries are stored
by hardware ID (`vendor:product`, e.g. `045e:028e`), so a blacklisted device stays
blacklisted across replugs, reloads, and restarts.

## Notes

- Uses the `xinput` and `winmm` libraries, which are native to Windows and bundled
  in Proton.
- Only the runtime gamepad setting, Disable Enumeration, is toggled. No game configuration is changed
  permanently.
- To turn the addon off, unload it: `/addon unload controllerfix`.

## Acknowledgements

Inspired by [gamepadfix](https://github.com/AddonsXI/gamepadfix) from AddonsXI,
which fixes the same no-controller input stutter by toggling FFXI's gamepad
setting. `controllerfix` builds on that approach with DirectInput detection and
a per-device blacklist.

## License

GPL-3.0. See [LICENSE](LICENSE).
