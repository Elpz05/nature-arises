# Tower scenes and roles

Both levels use the same `semillas_escenas` order as `hud.gd` and saved plant unlocks:

| Index | Plant | Scene | Initial cost | Upgrade costs |
| --- | --- | --- | --- | --- |
| 0 | Natura | `res://escenas/escenas_arboles/arbol_base.tscn` | 1 | 2, 3 |
| 1 | Flamma | `res://escenas/escenas_arboles/arbol_flamma.tscn` | 3 | 4, 5 |
| 2 | Aqua | `res://escenas/escenas_arboles/arbol_aqua.tscn` | 6 | 8, 10 |

The other four slots remain unimplemented. Do not reorder these indices: saves
store the numeric plant IDs.

## Scene wiring

`nivel_0.tscn` and `nivel_1.tscn` now assign all three scenes in their root node's
**Semillas Escenas** array. Existing `desbloqueos = [1, 2]` awards Flamma and Aqua
after completing level 0. The HUD loads saved plant IDs through
`Guardado.plantas_activas()`; new players still begin with Natura only.

To test manually, complete level 0 and continue to level 1. Flamma costs three
drops and Aqua costs six, so Aqua's button stays disabled until enough drops
have accumulated. Existing saves with plants 1 and 2 already unlocked also work.
Running a level directly with F6 and no selected save slot retains Natura-only
defaults. The automated test supplies unlocks in memory without changing saves.

The two new scenes inherit `arbol_elemental_base.tscn`:

```text
ArbolElemental (Node2D, arbol.gd)
  Arbol (AnimatedSprite2D, empty frames)
    Placeholder (Polygon2D)
    Rango (Area2D, mask 1)
      CollisionShape2D (circle created from upgrade stats)
  TemporizadorDisparo (Timer)
```

Flamma uses an orange triangle and Aqua a blue diamond. No image assets were
created. The shared script exposes damage, shots per second, costs, splash
radius, slow factor/duration, and projectile color in the Inspector. It connects
range entry/exit and the firing timer in `_ready()`, just like Natura.

## Combat flow

1. The level instantiates the chosen scene and connects `murio` to cell cleanup.
2. `Rango` collects enemies; the tower selects the one closest to the base by
   remaining path distance.
3. The tower configures an instance of the existing `bala.tscn` with its damage
   and role properties. Projectiles are added to the tower container and then
   positioned in global coordinates.
4. On impact, Flamma snapshots living enemies within 64 pixels of its target
   and damages each once. Newly spawned Natura copies are not hit by that same
   explosion. Aqua damages its single target and calls `aplicar_lentitud()`.
5. Enemy movement applies the slow without changing its base `velocidad`.

| Tower | Base damage | Base shots/s | Role |
| --- | --- | --- | --- |
| Natura | 20 | 2.0 | Cheap single-target damage |
| Flamma | 30 | 0.8 | Splash within one cell of the impact target |
| Aqua | 10 | 1.0 | Single target; 40% slower for 2 seconds |

All towers retain the existing upgrade range progression (2 / 2.5 / 3 cells)
and firing-rate multipliers (1 / 1.2 / 1.5). Flamma's splash radius and Aqua's
slow remain constant across upgrades. The shovel refunds all invested drops.

Aqua slows do not multiply: equal-strength hits refresh the timer, stronger
slows replace weaker ones, and weaker slows are ignored while stronger ones
remain active. Slow timers continue expiring during a stun or revival stop.
These tower projectiles use ordinary damage; the existing player elemental
ability immunities/multipliers remain specific to those abilities.

These are initial balance values. Costs are still mirrored between HUD entries
and scene exports; moving them into shared definitions belongs in the upcoming
level/data refactor.

## Regression checks

Run with Godot 4.7.2 from the project directory:

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_tower_roles.gd --quit-after 240
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_critical_fixes.gd --quit-after 240
```

The tower checks cover locked selection, unlocked planting in both levels,
actual range detection, splash inclusion/exclusion, single-impact handling,
slow movement/refresh/expiration, upgrades, and refunds. Both scripts print a
PASS/FAILED result; an early script error must not be treated as a pass.
