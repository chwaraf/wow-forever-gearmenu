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
  Spec for the debug log switch in code/Logger.lua: which log levels reach the chat frame with the
  "Enable Debug Log" option off (the default) and on.

  The switch is a player setting, so the logger reads it from the configuration module on every log
  call instead of caching it at load time. This spec drives that seam directly: the bootstrap's
  configuration stand-in has no IsDebugLogEnabled, so a stub answering from `debugLogEnabled` is
  installed before the logger is re-dofile'd.

  print is captured by replacing the global and the tag filter is replaced by one that lets
  everything through; the addon title a line is prefixed with comes from WowStubs. The environment
  shim is the development build (debug level, event log shipped on) - the case the switch exists
  for. The release build's error level is not reachable from here (RGGM_ENVIRONMENT is a constant),
  but it is the lower bound of the same comparison: with the switch off the level is at most warn,
  so an error always prints.

  The Log* functions are the addon's own diagnostics; PrintUser* is the player facing feedback and
  is deliberately not gated by any of this, so it is pinned here too.
]]--

local wowStubs = require("WowStubs")

-- log line colors, duplicated from code/Logger.lua on purpose: the assertion is about what a player
-- sees in the chat frame, so a color change should have to touch this spec
local DEBUG_COLOR = "|cff7413d9"
local INFO_COLOR = "|cff18f3ff"
local WARN_COLOR = "|cffffce01"
local ERROR_COLOR = "|cfff00000"
local EVENT_COLOR = "|cff1cdb4f"

describe("Logger", function()
  local logger
  local printed
  -- state the configuration stub answers IsDebugLogEnabled from
  local debugLogEnabled
  local previous
  local restore

  --[[
    Number of captured lines written with the given level color

    @param {string} color

    @return {number}
  ]]--
  local function linesWithColor(color)
    local count = 0

    for _, line in ipairs(printed) do
      if string.find(line, color, 1, true) then
        count = count + 1
      end
    end

    return count
  end

  before_each(function()
    printed = {}
    debugLogEnabled = false

    previous = {
      logger = rggm.logger,
      filter = rggm.filter,
      configuration = rggm.configuration,
      event = rggm.event
    }

    restore = wowStubs.install({
      print = function(message) printed[#printed + 1] = message end,
      C_AddOns = wowStubs.stubs.C_AddOns({ Title = "GearMenu" })
    })

    -- a filter that lets every tag through - the real patterns are covered by FilterSpec
    rggm.filter = { ShouldFilterTag = function() return false end }
    rggm.configuration = {
      IsDebugLogEnabled = function() return debugLogEnabled end
    }

    dofile("code/Logger.lua")
    logger = rggm.logger
  end)

  after_each(function()
    restore()

    for name, value in pairs(previous) do
      rggm[name] = value
    end
  end)

  describe("with the debug log off", function()
    it("writes no debug lines", function()
      logger.LogDebug("Test", "details")

      assert.are.equal(0, #printed)
    end)

    it("writes no event lines even though the development build ships the event log", function()
      assert.is_true(logger.logEvent)

      logger.LogEvent("Event", "BAG_UPDATE")

      assert.are.equal(0, #printed)
    end)

    it("caps the development build's debug level at warnings and errors", function()
      logger.LogInfo("Test", "started")
      logger.LogWarn("Test", "careful")
      logger.LogError("Test", "broken")

      assert.are.equal(0, linesWithColor(INFO_COLOR))
      assert.are.equal(1, linesWithColor(WARN_COLOR))
      assert.are.equal(1, linesWithColor(ERROR_COLOR))
    end)

    it("formats a printed line as color, addon title, tag and message", function()
      logger.LogError("Test", "broken")

      assert.are.equal(ERROR_COLOR .. "GearMenu:Test - broken", printed[1])
    end)
  end)

  --[[
    Each test sets the switch itself instead of a nested before_each, so the state a test starts
    from is visible in the test body
  ]]--
  describe("with the debug log on", function()
    it("writes debug lines", function()
      debugLogEnabled = true

      logger.LogDebug("Test", "details")

      assert.are.equal(1, linesWithColor(DEBUG_COLOR))
      assert.is_truthy(string.find(printed[1], "details", 1, true))
    end)

    it("writes event lines", function()
      debugLogEnabled = true

      logger.LogEvent("Event", "BAG_UPDATE")

      assert.are.equal(1, linesWithColor(EVENT_COLOR))
    end)

    it("raises the level so info lines are written as well", function()
      debugLogEnabled = true

      logger.LogInfo("Test", "started")

      assert.are.equal(1, linesWithColor(INFO_COLOR))
    end)

    it("still writes the event line only in a build that ships the event log", function()
      debugLogEnabled = true
      logger.logEvent = false

      logger.LogEvent("Event", "BAG_UPDATE")

      assert.are.equal(0, #printed)
    end)
  end)

  it("keeps warnings and errors flowing while the configuration module is not loaded yet", function()
    rggm.configuration = nil

    logger.LogDebug("Test", "details")
    logger.LogEvent("Event", "BAG_UPDATE")
    logger.LogError("Test", "broken")

    assert.are.equal(1, #printed)
    assert.are.equal(1, linesWithColor(ERROR_COLOR))
  end)

  it("logs without raising while the saved variables are not assigned yet", function()
    local savedConfiguration = _G.GearMenuConfiguration
    _G.GearMenuConfiguration = nil

    logger.LogDebug("Test", "details")
    logger.LogEvent("Event", "BAG_UPDATE")
    logger.LogWarn("Test", "careful")

    _G.GearMenuConfiguration = savedConfiguration

    assert.are.equal(1, #printed)
    assert.are.equal(1, linesWithColor(WARN_COLOR))
  end)

  it("shows player facing messages regardless of the debug log", function()
    logger.PrintUserMessage("Profile saved")
    logger.PrintUserChatWarn("Equipped a substitute copy")
    logger.PrintUserChatError("Import failed")

    assert.are.equal(3, #printed)
  end)

  it("gates the event bus log through the same switch", function()
    dofile("code/Event.lua")
    rggm.event.Register("PLAYER_ENTERING_WORLD", function() end)

    rggm.event.Dispatch("PLAYER_ENTERING_WORLD")
    assert.are.equal(0, #printed)

    debugLogEnabled = true
    rggm.event.Dispatch("PLAYER_ENTERING_WORLD")
    assert.are.equal(1, linesWithColor(EVENT_COLOR))
  end)
end)
