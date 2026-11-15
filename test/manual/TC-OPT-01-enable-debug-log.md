# TC-OPT-01 — Enable Debug Log

**Area:** General options | **Client:** Forever | **Mandatory:** yes

## Preconditions

- A fresh install or a configuration whose `enableDebugLog` was never switched on
- `/console scriptErrors 1` so nothing is swallowed

## Steps

1. Open `/rggm opt` and select the general settings page
2. Verify the unchecked state of **Enable Debug Log** and watch the chat frame while idling
3. Tick **Enable Debug Log**, then trigger addon activity (open and close bags, swap an item,
   change the target, zone into an instance)
4. Untick **Enable Debug Log** and repeat the activity from step 3
5. Tick it again and run `/reload`
6. Open the SavedVariables file while logged out and read `enableDebugLog`

## Expected

- Step 2: the box is unchecked after a fresh install and after an upgrade, and the chat frame stays
  quiet - no debug or event lines. A warning or an error from the addon still prints
- Step 3: the chat frame fills with `GearMenu:Event - <EVENT>` lines, one per handled event, plus
  the debug lines (`GearMenu:<Module> - ...`). BAG_UPDATE alone produces one line per changed bag
- Step 4: debug and event lines stop immediately, without a reload. Warnings and errors keep
  printing
- Step 5: the box is checked again after the reload and the event log continues, i.e. the setting is
  persisted and applied at login rather than only for the current session
- Step 6: `enableDebugLog = true` after step 5, `false` after step 4
- No Lua errors in any step

## Notes

- The switch only ever adds output: it cannot silence a warning or an error, and it does not
  gate the player facing messages (`GearMenu:User - ...`) that confirm an action
- The setting is a client preference, not part of a profile: exporting a profile while it is on,
  then importing it on another character, leaves that character's switch alone, and
  "Reset to defaults" does not clear it either
- Development builds ship with the debug log level and the event log; release builds ship without
  the event log, so on a release the event lines are absent even with the box ticked. Both are
  covered by the busted spec `LoggerSpec`
