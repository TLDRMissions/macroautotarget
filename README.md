# Macro Auto Target
[Originally ArenaTargetHealer] Changes the "target=" in your macros based on which slot an enemy/friendly role is in

If you create a macro that has "#ATH" in it somewhere, it will update the "/tar arena1" part to the slot that has an enemy healer.

Example macro. If you create one that reads like this:

    #ATH
    /tar arena1
    /cast Polymorph

During the prep phase of arena, if the enemy healer is in slot 2, it will be changed to:

    #ATH
    /tar arena2
    /cast Polymorph

 Also works for `/target arena1`, `/focus arena1`, and `/cast [@arena1]`.

 Supported commands:

- #ATH: target first enemy arena healer
- #ATT: target first enemy arena tank
- #ATD: target first enemy arena dps
- #RTH: target first friendly party/raid healer
- #RTT: target first friendly party/raid tank
- #RTD: target first friendly party/raid dps
- Optional number at the end of the command, to pick the second/third/etc tank/healer/dps in your party/raid.
- - Eg
  - #RTD2: target second friendly party/raid dps
