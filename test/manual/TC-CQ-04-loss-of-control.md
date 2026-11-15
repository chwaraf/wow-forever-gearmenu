# TC-CQ-04 — Queue during loss of control

**Area:** CombatQueue | **Client:** Forever | **Mandatory:** yes

## Preconditions

- A repeatable loss-of-control effect on the player. Out-of-combat options: another player's
  sap/fear in a duel, or a mob with a stun/fear. (Any effect that triggers
  `LOSS_OF_CONTROL_ADDED` works.)
- Script errors enabled (`/console scriptErrors 1`) - the error this case guards against is a Lua
  error, not a wrong swap

## Steps

1. Get affected by the loss-of-control effect
2. While under the effect (and otherwise out of combat), click an alternative item in the ChangeMenu
3. Wait for the effect to expire

## Expected

- No Lua error at any point, in particular none of
  `CombatQueue.lua: attempted to index a table that cannot be indexed with secret keys` - the
  client hands the effect's `locType` to addons as a secret value on Forever
- While under loss of control the swap is queued, not executed
- Once the effect ends (`LOSS_OF_CONTROL_UPDATE` clears the block flag), the queued swap
  fires as soon as no other block (combat/cast) applies
- The queued-item overlay clears

## Notes

Repeat with a *root* (e.g. a mage's Frost Nova in a duel, or Entangling Roots): a root does not
prevent an equipment change, so the swap must happen right away rather than wait for it to expire.
The client withholds the type of both effects, so `CombatQueue` tells them apart by the effect's
priority, which the client never withholds - a root is the lowest one.
