--[[
  MIT License

  Copyright (c) 2026 Michael Wiesendanger

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

-- luacheck: read globals C_AddOns UIErrorsFrame

local mod = rggm
local me = {}

mod.logger = me

me.tag = "Logger"

--[[
  LogLevels {number}

  debug - 4
  info - 3
  warn - 2
  error - 1
  event - 0
]]--
me.debug = 4
me.info = 3
me.warn = 2
me.error = 1
me.event = 0

me.logLevel = RGGM_ENVIRONMENT.LOG_LEVEL

--[[
  LogEvents {boolean}

  Whether this build logs events at all - only development builds ship it enabled. Whether the log
  actually prints is decided by the debug log switch, see LogEvent
]]--
me.logEvent = RGGM_ENVIRONMENT.LOG_EVENT

--[[
  Whether the debug log - the LogDebug lines and the event log - is switched on. This is a player
  setting (options > Enable Debug Log, off by default), not a build property.

  Resolved lazily on each log call instead of once at load time: Logger.lua is loaded before
  Configuration.lua and the saved value is only backfilled by Configuration.SetupConfiguration, so
  a value read at load time would miss both the stored setting and a change made in the options.

  @return {boolean}
]]--
local function IsDebugLogEnabled()
  --[[ the saved variables exist from the first line the client runs, but a log call must never be
       the thing that raises - a log line that fails would hide the error it was meant to report ]]--
  if GearMenuConfiguration == nil or mod.configuration == nil
    or mod.configuration.IsDebugLogEnabled == nil then
    return false
  end

  return mod.configuration.IsDebugLogEnabled()
end

--[[
  The log level the LogInfo / LogWarn / LogError calls compare against.

  The build's level (RGGM_ENVIRONMENT.LOG_LEVEL) is the baseline - a development build ships with
  the debug level, a release build with the error level. Switching the debug log on raises the
  baseline to debug so the whole log is visible; switching it off caps it at warn, which makes a
  development build as quiet as a release plus the warnings that are worth showing. Either way
  warnings and errors are never suppressed: they are sparse and often the only trace a player has
  of a problem.

  @return {number}
]]--
local function GetLogLevel()
  if IsDebugLogEnabled() then
    return me.debug
  end

  if me.logLevel > me.warn then
    return me.warn
  end

  return me.logLevel
end

--[[
  LogLevel colors
]]--
me.colors = {}
me.colors.error = "|cfff00000"  -- red
me.colors.warn = "|cffffce01"   -- yellow
me.colors.info = "|cff18f3ff"   -- blue
me.colors.debug = "|cff7413d9"  -- magenta
me.colors.event = "|cff1cdb4f"  -- green

local userMessageTag = "User"

--[[
  Writes string message to the default chat frame

  @param {string} levelColor
  @param {string} tag
  @param {string} message
]]--
local PrintLogMessage = function(levelColor, tag, message)
  if tag == nil then
    tag = "Unknown"
  end

  if not mod.filter.ShouldFilterTag(tag) then
    print(levelColor .. C_AddOns.GetAddOnMetadata(RGGM_CONSTANTS.ADDON_NAME, "Title") .. ":" .. tag .. " - " .. message)
  end
end

--[[
  Detailed diagnostics. Off unless the player switched the debug log on - a development build
  necessarily ships with the debug log level, so the switch, not the level, decides here.

  @param {string} tag
  @param {string} message
]]--
function me.LogDebug(tag, message)
  if IsDebugLogEnabled() then

    PrintLogMessage(me.colors.debug, tag, message)
  end
end

--[[
  @param {string} tag
  @param {string} message
]]--
function me.LogInfo(tag, message)
  if GetLogLevel() >= me.info then
    PrintLogMessage(me.colors.info, tag, message)
  end
end

--[[
  @param {string} tag
  @param {string} message
]]--
function me.LogWarn(tag, message)
  if GetLogLevel() >= me.warn then
    PrintLogMessage(me.colors.warn, tag, message)
  end
end

--[[
  @param {string} tag
  @param {string} message
]]--
function me.LogError(tag, message)
  if GetLogLevel() >= me.error then
    PrintLogMessage(me.colors.error, tag, message)
  end
end

--[[
  The event log prints one line per event the addon handles, which is a lot (BAG_UPDATE alone
  fires once per bag), so it needs both: a build that ships the event log and a player who switched
  the debug log on.

  @param {string} tag
  @param {string} message
]]--
function me.LogEvent(tag, message)
  if me.logEvent and IsDebugLogEnabled() then
    PrintLogMessage(me.colors.event, tag, message)
  end
end

--[[
  Display a message in the standard error frame

  @param {string} msg
]]--
function me.PrintUserError(msg)
  UIErrorsFrame:AddMessage(msg, 1.0, 0.0, 0.0, 1.0, 53)
end

function me.PrintUserChatError(message)
  PrintLogMessage(me.colors.error, userMessageTag, message)
end

--[[
  Display a user facing warning message in the default chat frame. Unlike the Log*
  functions this is always shown - it is not gated by the log level - and is meant
  for direct feedback on an action that succeeded with a caveat (e.g. a swap that
  equipped a substitute copy of the requested item).

  @param {string} message
]]--
function me.PrintUserChatWarn(message)
  PrintLogMessage(me.colors.warn, userMessageTag, message)
end

--[[
  Display a user facing informational message in the default chat frame. Unlike
  the Log* functions this is always shown - it is not gated by the log level - and
  is meant for direct feedback on a user action (e.g. saving or applying a profile).

  @param {string} message
]]--
function me.PrintUserMessage(message)
  PrintLogMessage(me.colors.info, userMessageTag, message)
end
