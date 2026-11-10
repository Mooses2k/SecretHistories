class_name AIStateCombat
extends HFSM

## The combat sub-machine (owner decision 3: sub-machine now). Runs the
## Approach / GunAttack / MeleeAttack children; the parent machine evaluates
## THIS state's own table to leave combat (for example on guard_no_target or
## guard_alert_below_investigate). Reposition stays deferred.
