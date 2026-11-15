# TC-OPT-02 — Minimap button

**Area:** General options / minimap | **Client:** Forever | **Mandatory:** yes

## Preconditions

- A fresh install or any configuration whose `minimapButton` was never changed
- Optional, for the third pass: Leatrix Plus with *Enhance minimap → Combine addon buttons* enabled
  (or any button collector such as MinimapButtonButton)

## Steps

1. Log in and look at the minimap
2. Hover the icon; then left click it; close the settings and left click again
3. Drag the icon around the minimap ring, then `/reload`
4. Right click the icon, then `/reload`
5. Open `/rggm opt` → general options, tick **Show Minimap Button**, close and reopen the panel
6. If Leatrix Plus is available: enable *Combine addon buttons*, open the button bag, hover the
   GearMenu entry, left click it. Then disable *Combine addon buttons*
7. Log out and read `GearMenuConfiguration.minimapButton` from the SavedVariables file

## Expected

- Step 1: a round GearMenu icon sits on the minimap ring with a tooltip naming the addon
- Step 2: the tooltip reads "Left click: open the options" and "Right click: hide this icon"; both
  clicks open the GearMenu settings panel
- Step 3: the icon follows the cursor while dragged and stays where it was dropped, across the
  reload. `minimapButton.minimapPos` in the SavedVariables changes with it
- Step 4: the icon disappears immediately, `/reload` keeps it hidden, and a chat line points to the
  option that brings it back
- Step 5: the checkbox is unchecked while the icon is hidden and checked after it is re-enabled; the
  icon appears/disappears without a reload. Keybindings and the gearBars are unaffected either way
- Step 6: Leatrix Plus treats the icon as a standard LibDBIcon button - it is moved into the button
  bag, hidden and shown with the other addon buttons, fades with the minimap, and its tooltip and
  texture are the GearMenu ones (no "non-standard button" stand-in, no generic texture)
- Step 7: `minimapButton = { hide = <false|true>, minimapPos = <the dragged angle> }` - the position
  from step 3 is still there after hiding and showing the icon again
- No Lua errors in any step

## Notes

- The icon is a LibDataBroker launcher rendered by LibDBIcon-1.0; both libraries are embedded under
  `libs/` (see [libs/README.md](../../libs/README.md)). Nothing has to be installed for the icon to
  appear
- A data broker display other than LibDBIcon (Bazooka, ChocolateBar, TitanPanel) shows the same entry
  and its click behavior, so the launcher is worth a pass there if one is installed
- Hiding the icon is not a teardown: the data object stays registered, which is what makes the
  checkbox take effect without a reload
