# FrostAtomUI

Personal UI replacement for World of Warcraft 3.3.5a: action bars, unit
frames, nameplates, chat, minimap and a handful of PvP conveniences.

## Layout

```
FrostAtomUI.toc        load order; Core/Bootstrap.lua must stay last
Bindings.xml           "Focus mouseover" entry in the Key Bindings window (mouse button 5 by default)
Core/
  Init.lua             namespace, module registry, ns.Mixin
  Util.lua             table/frame/format helpers
  Events.lua           event dispatcher (ns.EventMixin, ns:Fire)
  Media.lua            texture/font paths, ns.CreateBackdrop
  DB.lua               saved variables (ns.db, ns.DB_LOADED event)
  CVars.lua            pins cvars to a value
  Config.lua           nickname and screen positions (edit this to move things)
  Bootstrap.lua        calls every module's Initialize()
Modules/
  ActionBar/           bars 1-5, pet & shapeshift bars, /bind, click flash
  UnitFrames/          engine + Menu.lua (right-click menu) + Elements/ + Layout.lua
  Chat/                chat restyle, URL copy, /pm whisper block, history + /copy
  Misc/                tooltips, popups, arena timers, mouse wheel paging, ...
  NamePlates/          nameplates (ported from AtomNameplates, no dll), totem icons, target debuffs
  *.lua                one-file modules (minimap, runes, experience bar, player plate, ...)
```

Unit frames: player, pet, target (+ combo points), focus, targets of target and
focus, party (+ pets), arena (+ pets and trinket), boss1-4. Bars glide, lost
health leaves a fading strip, dispellable debuffs tint the health bar, buffs
the player can purge are framed. Own health and power also sit just below
the screen center as a small plate while in combat or hurt; warriors see the
equipped shield's icon next to it.

Automatic: greys are sold and gear repaired at merchants (hold Shift to skip),
invites from friends/guild mates are accepted, own interrupts are announced,
BG messages show as raid warnings, enemy BG healers get an icon on their
nameplate, the "DELETE" confirmation is typed for you, "+ combat"/"- combat"
flashes on screen. Character and inspect windows show item levels on every
slot and the average under the model; the model is rotated/moved/zoomed with
the mouse. Chat links show a tooltip on hover and the last 100 lines come
back after a reload.

Every file starts with `local _, ns = ...`; `ns` is the shared addon table.
A module is `ns:NewModule("Name")` and subscribes to events with
`module:RegisterEvent(event, handlerOrMethodName)`. Frames get the same API via
`ns.Mixin(frame, ns.EventMixin)`.

## Slash commands

| Command | |
|---|---|
| `/bind`, `/b` | keybinding mode for action buttons |
| `/pm` | block whispers from strangers |
| `/copy` | window to copy the current chat frame's text from |
| `/ia` | toggle interrupt announcements to the group |
| `/noduel` | auto-decline duels |
| `/vr` | disable the click animation (video recording) |
| `/guid` | print target's GUID |
| `/rl` | reload UI |

## Development

Formatting is done with [StyLua](https://github.com/JohnnyMorganz/StyLua)
(config in `stylua.toml`), linting with
[luacheck](https://github.com/lunarmodules/luacheck) (config in `.luacheckrc`).

```
npm install            # installs stylua
npm run format         # format everything
npm run format:check   # CI-style check
luacheck .             # needs luacheck on PATH
```

Both checks run on GitHub Actions for every push and pull request
(`.github/workflows/lint.yml`).
