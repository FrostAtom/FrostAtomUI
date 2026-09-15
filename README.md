# FrostAtomUI

Personal UI replacement for World of Warcraft 3.3.5a: action bars, unit
frames, nameplates, chat, minimap and a handful of PvP conveniences.

## Layout

```
FrostAtomUI.toc        load order; Core/Bootstrap.lua must stay last
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
  Chat/                chat restyle, URL copy, /pm whisper block
  Misc/                tooltips, popups, arena timers, mouse wheel paging, ...
  NamePlates/          nameplates (ported from AtomNameplates, no dll), totem icons, target debuffs
  *.lua                one-file modules (minimap, runes, experience bar, ...)
```

Unit frames: player, pet, target (+ combo points), focus, targets of target and
focus, party (+ pets), arena (+ pets and trinket), boss1-4.

Every file starts with `local _, ns = ...`; `ns` is the shared addon table.
A module is `ns:NewModule("Name")` and subscribes to events with
`module:RegisterEvent(event, handlerOrMethodName)`. Frames get the same API via
`ns.Mixin(frame, ns.EventMixin)`.

## Slash commands

| Command | |
|---|---|
| `/bind`, `/b` | keybinding mode for action buttons |
| `/pm` | block whispers from strangers |
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
