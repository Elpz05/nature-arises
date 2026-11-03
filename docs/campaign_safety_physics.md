# Campaign completion, save safety and combat cleanup

## Campaign ending

`Guardado.NIVELES` is the source of campaign length. `es_ultimo_nivel()` identifies
the final playable level, and `NivelBase._ganar_nivel()` passes that status to the
victory overlay. Clearing level 0 still offers Next Level and unlock information.
Clearing level 1 displays **¡Campaña completada!**, with **Volver a partidas** and
**Menú principal** buttons. It has no next-level/restart-campaign button.

`campana_completada.tscn` inherits the existing victory scene and is also usable
as a standalone outcome. Loading a completed slot routes there instead of level 0
or replaying level 1. Save-slot labels now use the actual two-level campaign
length and explicitly mark completed slots.

`Guardado.escena_para_nivel()` centralizes routing. Progress at or above the
campaign length routes to the completion scene. Invalid negative level requests
return to the slots menu. Victory handlers also reject stale next-level calls on
the final outcome. Menu focus and existing InputMap bindings remain available.

## Save validation and recovery

The recognized version-1 schema is:

```json
{
  "version": 1,
  "nivel_actual": 0,
  "niveles_completados": [],
  "plantas": [0],
  "ataques": [0],
  "campana_completada": false
}
```

`validar_datos(Variant)` normalizes every read and all progression/unlock writes:

- Non-dictionary roots fall back to fresh defaults.
- Progress accepts whole JSON numbers and legacy integer strings. Booleans,
  fractions, non-finite numbers, objects and invalid strings fall back safely.
- Progress is bounded by campaign length; completion cannot regress on a replay.
- Completed-level and unlock arrays are range-checked, deduplicated and sorted.
  Invalid array fields and invalid entries are ignored. Natura remains unlocked.
- Legacy progress restores missing completed-level entries and level-0 rewards
  (Flamma/Aqua plants and the Flamma ability).
- Final progress, final-level completion, or an explicit boolean completion flag
  marks the campaign complete. Legacy `nivel_actual = 2` saves therefore load the
  final screen. Unknown JSON fields are retained when normalizing.

`leer()` checks slot IDs, file access, a 1 MiB size limit and JSON parse results.
Damaged files load defaults with warnings rather than script exceptions. Reading
does not modify the source file. On the first later write of repaired/legacy data,
the original file is preserved as `.bak` if no backup already exists. A failure to
create that backup aborts the write. Existing backups are not overwritten.

`guardar()` writes and flushes `.tmp`, then replaces the destination through
`DirAccess.rename_absolute()`. Failed writes/replacements return false and retain
the old destination. This avoids truncating the existing slot at the start of a
save; it does not promise protection from every possible disk/power failure.
Explicit slot deletion removes that slot's main, `.tmp` and `.bak` files only.
See the [Godot DirAccess API](https://docs.godotengine.org/en/stable/classes/class_diraccess.html#class-diraccess-method-rename-absolute).

## Physics and target lifecycle

Enemy path movement, slow/stun timing and arrival detection now live in
`espiritu.gd::_physics_process(delta)`. Tower `_physics_process()` refreshes its
targets from Area2D's cached overlap list. Detection no longer depends on a
manually maintained body-entered/body-exited array.

The firing Timer uses `Timer.TIMER_PROCESS_PHYSICS`, so its callbacks run in the
same update phase. Its meaning is documented in the
[Godot Timer API](https://docs.godotengine.org/en/stable/classes/class_timer.html#enum-timer-timerprocesscallback).
Projectiles retain their existing clamped movement/hit logic.

`Arbol._es_objetivo_valido()` rejects invalid/freed references, dead enemies,
queued enemy bodies, queued PathFollow2D parents, missing paths and queued paths.
Both cleanup and target selection apply this guard. Firing rechecks validity and
`Area2D.overlaps_body()` before creating a projectile. No full-tree enemy scan is
added to tower physics updates.

Tests that manually advance enemy effects now invoke `_physics_process()` and
disable physics when freezing enemy movement. UI and level frame-update tests
continue using `_process()`.

## Regression suites

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_campaign_safety.gd --quit-after 600
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_combat_physics.gd --quit-after 600
```

Campaign/save tests create a unique private directory under `tests/` and clean up
only its fixtures. They check malformed/oversized JSON, bad fields, legacy rewards,
backup contents, repeated replacement, failed writes, routing and both victory
overlays. Physics tests run actual ticks, verify range entry/exit and reject
freed/dead/queued bodies and followers before another physics tick. Neither suite
touches player slots. The six existing regression suites remain applicable.
