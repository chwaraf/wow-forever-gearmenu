--[[
  MIT License

  Copyright (c) 2026 Michael Wiesendanger

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
]]--

-- luacheck: read globals LibStub

--[[
  The minimap button.

  Rendered through LibDataBroker-1.1 + LibDBIcon-1.0 rather than an own button parented to the
  Minimap. Those are the libraries the minimap addons look for: Leatrix Plus, SexyMap and the
  button collectors size, sort, hide and fade a button by walking LibDBIcon's registry, so a
  hand-rolled button is either left out of the collection or replaced by a stand-in (Leatrix Plus
  calls those "non-standard buttons" and loses the tooltip and often the texture). Registering
  through LibDBIcon - and shipping it, so the icon exists without another addon providing it - is
  what makes GearMenu's icon behave like every other addon icon on the ring.

  The data object is also the addon's launch point for everything that is not the settings panel,
  so a data broker display that is not LibDBIcon (Bazooka, ChocolateBar, TitanPanel) shows a
  working GearMenu entry instead of an empty one.
]]--

local mod = rggm
local me = {}

mod.minimapButton = me

me.tag = "MinimapButton"

--[[
  The name the data object and the minimap button are registered under. Data broker displays list
  data objects by this name, so it is the addon's display name and not a frame name
]]--
local BUTTON_NAME = RGGM_CONSTANTS.ADDON_NAME

--[[
  Whether the icon was already set up. Core.Initialize runs once per login or /reload, but a
  failing step is retried by the player with /reload, and LibDBIcon errors on a duplicate name
]]--
local isRegistered = false

--[[
  Build the tooltip of the icon - what the left click does, plus the way to hide the icon

  @param {table} tooltip
]]--
local function ShowTooltip(tooltip)
  tooltip:SetText(rggm.L["minimap_button_tooltip_title"])

  if mod.addonConfiguration.IsCategoryRegistered("general") then
    tooltip:AddLine(rggm.L["minimap_button_tooltip_click"])
  end

  tooltip:AddLine(rggm.L["minimap_button_tooltip_hide"], 1, 1, 1, true)
end

--[[
  Open the addon configuration
]]--
local function OpenConfiguration()
  mod.addonConfiguration.OpenMainCategory()
end

--[[
  Hide the icon and persist the choice. Reachable from the icon's own tooltip because the icon is
  the one thing a player cannot find their way back from: without it there is still /rggm opt.
]]--
local function HideButton()
  mod.configuration.DisableMinimapButton()
  mod.logger.PrintUserMessage(rggm.L["minimap_button_hidden"])
end

--[[
  Create the data object and hand it to LibDBIcon

  @param {table} ldb
    LibDataBroker-1.1
  @param {table} ldbIcon
    LibDBIcon-1.0
]]--
local function Register(ldb, ldbIcon)
  local dataObject = ldb:NewDataObject(BUTTON_NAME, {
    type = "launcher",
    icon = RGGM_CONSTANTS.MINIMAP_BUTTON_ICON,
    OnClick = function(_, button)
      if button == "LeftButton" then
        OpenConfiguration()
      elseif button == "RightButton" then
        HideButton()
      end
    end,
    OnTooltipShow = ShowTooltip
  })

  ldbIcon:Register(BUTTON_NAME, dataObject, GearMenuConfiguration.minimapButton)

  isRegistered = true

  mod.logger.LogInfo(me.tag, "Registered the minimap button")
end

--[[
  Create and register the minimap button.

  Runs during Core.Initialize, i.e. inside the PLAYER_ENTERING_WORLD bootstrap and after
  Configuration.SetupConfiguration backfilled the button's saved position. Registration happens
  even while the icon is hidden - LibDBIcon keeps a hidden icon registered, so switching it back on
  needs no reload.

  A missing library is not an error: the addon works without an icon (the /rggm commands and the
  Blizzard addon options remain), and shipping the libraries makes this a "the .toc did not load
  them" case rather than a player choice
]]--
function me.Setup()
  if isRegistered then return end

  local ldb = LibStub("LibDataBroker-1.1", true)
  local ldbIcon = LibStub("LibDBIcon-1.0", true)

  if ldb == nil or ldbIcon == nil then
    mod.logger.LogWarn(me.tag, "LibDataBroker-1.1 or LibDBIcon-1.0 is missing - no minimap button")

    return
  end

  Register(ldb, ldbIcon)
end

--[[
  Apply the current show/hide state to the icon without re-registering it.

  LibDBIcon reads the db table it was registered with on every show, so passing the saved table
  back through Refresh is all a toggle needs - the player sees the icon appear or disappear without
  a reload. A no-op while the libraries are missing or before Setup ran
]]--
function me.Refresh()
  if not isRegistered then return end

  local ldbIcon = LibStub("LibDBIcon-1.0", true)

  if ldbIcon == nil then return end

  ldbIcon:Refresh(BUTTON_NAME, GearMenuConfiguration.minimapButton)
end

--[[
  @return {boolean}
    true - if the icon was registered this session
]]--
function me.IsRegistered()
  return isRegistered
end
