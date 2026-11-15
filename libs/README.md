# Embedded libraries

Vendored, unmodified copies of the libraries the minimap button is built on. They are embedded
rather than declared as dependencies so the icon works on a fresh install without the player
installing anything else, and so a minimap addon that already ships a different copy finds a
compatible one (`LibStub` hands out the newest minor version, and the files below are the newest
released ones).

Loaded from `libs/embeds.xml` in the `.toc`, before any addon code:

| Library | Version | What it does | Upstream |
|---------|---------|--------------|----------|
| `LibStub` | 2 | Versioned registry - how the other libraries and GearMenu find each other | https://github.com/tekkub/libstub (public domain) |
| `CallbackHandler-1.0` | 7 | Callback registry used by LibDataBroker's change notifications | https://repos.wowace.com/wow/callbackhandler (WoW AddOns license) |
| `LibDataBroker-1.1` | 4 | Publishes a data object ("launcher") that data broker displays can render | https://github.com/tekkub/libdatabroker-1-1 |
| `LibDBIcon-1.0` | 44 | Draws and positions the round minimap icon for a data object, saves its position | https://www.curseforge.com/wow/addons/libdbicon-1-0 (GPLv2 or later) |

`LibDBIcon-1.0` is what minimap addons look for: Leatrix Plus, SexyMap and the button collectors
walk its object registry to size, sort, hide and fade addon icons. A button of our own parented to
`Minimap` is invisible to them - Leatrix Plus replaces such buttons ("non-standard buttons") with a
stand-in and loses the tooltip and often the texture on the way. Registering through LibDBIcon is
therefore not a style choice.

## Updating

Copy the files from upstream verbatim - no local edits, so a later update is a plain overwrite:

```
LibStub/LibStub.lua
CallbackHandler-1.0/CallbackHandler-1.0.lua
LibDataBroker-1.1/LibDataBroker-1.1.lua
LibDBIcon-1.0/LibDBIcon-1.0.lua
LibDBIcon-1.0/lib.xml
```

Then bump the version in the table above. `libs/` is excluded from `luacheck` (see `.luacheckrc`)
and from the headless specs - the libraries want the client's string aliases and frame API from
their first line, so "testing" them would mean testing a stub of the client rather than the library.
