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

--[[
  Spec for gui/MinimapButton.lua - the module that publishes GearMenu to LibDataBroker and hands it
  to LibDBIcon.

  LibStub, LibDataBroker and LibDBIcon themselves are vendored and not loaded here (they want the
  client's string aliases from their first line, and they are not ours to test). What is under test
  is the contract this addon has with them: the data object it publishes, what the icon does when
  clicked, and that the registration happens exactly once so LibDBIcon does not raise on a duplicate
  name. Both libraries are therefore recorders that capture what they are handed; the click, tooltip
  and visibility callbacks are then invoked directly.
]]--

local wowStubs = require("WowStubs")

describe("MinimapButton", function()
  local minimapButton
  local calls
  local previous
  local restore
  local config

  --[[
    A recorder for LibDBIcon-1.0

    @return {table}
  ]]--
  local function createIconStub()
    local icon = {}

    -- LibDBIcon is called with a colon, so the library table itself arrives as the first argument
    function icon.Register(_, name, dataObject, db)
      calls.registrations[#calls.registrations + 1] = {
        name = name, dataObject = dataObject, db = db
      }
    end

    function icon.Refresh(_, name, db)
      calls.refreshes[#calls.refreshes + 1] = { name = name, db = db }
    end

    return icon
  end

  before_each(function()
    calls = {
      dataObjects = {},   -- LibDataBroker:NewDataObject(name, object)
      registrations = {}, -- LibDBIcon:Register(name, object, db)
      refreshes = {},     -- LibDBIcon:Refresh(name, db)
      userMessages = {}   -- logger.PrintUserMessage(message)
    }

    config = { ["hide"] = false, ["minimapPos"] = 220 }
    _G.GearMenuConfiguration = { minimapButton = config }

    previous = {
      minimapButton = rggm.minimapButton,
      configuration = rggm.configuration,
      addonConfiguration = rggm.addonConfiguration,
      logger = rggm.logger,
      L = rggm.L
    }

    rggm.L = setmetatable({}, { __index = function(_, key) return key end })
    rggm.configuration = {
      DisableMinimapButton = function() config.hide = true end,
      IsMinimapButtonEnabled = function() return config.hide ~= true end
    }
    rggm.addonConfiguration = {
      OpenMainCategory = function() calls.mainCategoryOpened = true end,
      IsCategoryRegistered = function() return true end
    }
    rggm.logger = {
      LogInfo = function() end,
      LogWarn = function(_, message) calls.warning = message end,
      PrintUserMessage = function(message) calls.userMessages[#calls.userMessages + 1] = message end
    }

    local ldb = {
      NewDataObject = function(_, name, object)
        calls.dataObjects[#calls.dataObjects + 1] = { name = name, object = object }

        return object
      end
    }
    local ldbIcon = createIconStub()

    restore = wowStubs.install({
      LibStub = function(library, silent)
        if library == "LibDataBroker-1.1" then return ldb end
        if library == "LibDBIcon-1.0" then return ldbIcon end

        assert.is_truthy(silent)

        return nil
      end
    })

    dofile("gui/MinimapButton.lua")
    minimapButton = rggm.minimapButton
  end)

  after_each(function()
    restore()

    for name, value in pairs(previous) do
      rggm[name] = value
    end

    _G.GearMenuConfiguration = nil
  end)

  describe("Setup", function()
    it("publishes a launcher data object under the addon name", function()
      minimapButton.Setup()

      assert.are.equal(1, #calls.dataObjects)
      assert.are.equal(RGGM_CONSTANTS.ADDON_NAME, calls.dataObjects[1].name)
      assert.are.equal("launcher", calls.dataObjects[1].object.type)
      assert.are.equal(RGGM_CONSTANTS.MINIMAP_BUTTON_ICON, calls.dataObjects[1].object.icon)
    end)

    it("registers the data object with LibDBIcon together with the saved state table", function()
      minimapButton.Setup()

      assert.are.equal(1, #calls.registrations)
      assert.are.equal(RGGM_CONSTANTS.ADDON_NAME, calls.registrations[1].name)
      assert.are.equal(calls.dataObjects[1].object, calls.registrations[1].dataObject)
      -- LibDBIcon writes the dragged position and the hide flag into this very table
      assert.are.equal(config, calls.registrations[1].db)
      assert.is_true(minimapButton.IsRegistered())
    end)

    it("registers once, so a second call cannot hit LibDBIcon's duplicate-name error", function()
      minimapButton.Setup()
      minimapButton.Setup()

      assert.are.equal(1, #calls.registrations)
    end)

    it("warns instead of raising when the libraries are not loaded", function()
      restore()
      restore = wowStubs.install({
        LibStub = function() return nil end
      })

      minimapButton.Setup()

      assert.are.equal(0, #calls.registrations)
      assert.is_false(minimapButton.IsRegistered())
      assert.is_truthy(calls.warning)
    end)
  end)

  describe("icon callbacks", function()
    local dataObject

    before_each(function()
      minimapButton.Setup()
      dataObject = calls.dataObjects[1].object
    end)

    it("opens the configuration on left click", function()
      dataObject.OnClick(dataObject, "LeftButton")

      assert.is_true(calls.mainCategoryOpened)
    end)

    it("ignores other buttons", function()
      dataObject.OnClick(dataObject, "MiddleButton")
      dataObject.OnClick(dataObject, "RightButton")

      assert.is_nil(calls.mainCategoryOpened)
    end)

    it("hides the icon on right click and tells the player how to get it back", function()
      dataObject.OnClick(dataObject, "RightButton")

      assert.is_true(config.hide)
      assert.are.equal(1, #calls.userMessages)
    end)

    it("lists both clicks in the tooltip", function()
      local lines = {}
      local tooltip = {
        SetText = function(_, text) lines[#lines + 1] = text end,
        AddLine = function(_, text) lines[#lines + 1] = text end
      }

      dataObject.OnTooltipShow(tooltip)

      assert.are.equal("minimap_button_tooltip_title", lines[1])
      assert.are.equal("minimap_button_tooltip_click", lines[2])
      assert.are.equal("minimap_button_tooltip_hide", lines[3])
    end)

    it("drops the click hint while the options cannot be opened yet", function()
      local lines = {}
      local tooltip = {
        SetText = function(_, text) lines[#lines + 1] = text end,
        AddLine = function(_, text) lines[#lines + 1] = text end
      }

      rggm.addonConfiguration.IsCategoryRegistered = function() return false end

      dataObject.OnTooltipShow(tooltip)

      assert.are.equal(2, #lines)
      assert.are.equal("minimap_button_tooltip_hide", lines[2])
    end)
  end)

  describe("Refresh", function()
    it("hands the current state table back to LibDBIcon", function()
      minimapButton.Setup()

      minimapButton.Refresh()

      assert.are.equal(1, #calls.refreshes)
      assert.are.equal(RGGM_CONSTANTS.ADDON_NAME, calls.refreshes[1].name)
      assert.are.equal(config, calls.refreshes[1].db)
    end)

    it("does nothing before Setup ran", function()
      minimapButton.Refresh()

      assert.are.equal(0, #calls.refreshes)
    end)
  end)
end)
