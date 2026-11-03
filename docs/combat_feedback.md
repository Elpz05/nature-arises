> Actualización: las reglas de economía, pala, Flamma y Aqua de este documento han sido sustituidas por [el primer bloque de mecánicas](mecanicas_implementacion.md).

# Combat information

The feedback is implemented in the shared level, HUD, tower and enemy scripts,
so it works in both levels without changes to their child scripts or save data.
All visuals use existing fonts and simple shapes; no new art assets are needed.

## Tower inspection

- Hover over a planted tower to see a range circle and an information panel in
  the lower-left corner. Hovering never spends drops.
- Clicking a tower retains the existing click-to-upgrade behavior and pins its
  updated information when the mouse moves away. An unaffordable or max-level
  tower can also be inspected without changing it.
- Hovering another tower temporarily shows that tower instead. Confirming an empty
  board cell or using Atras / Clic Derecho clears the pinned inspection. Pausa
  opens the pause menu directly, including when a tool is selected.
- Using a planting/ability/shovel tool hides inspection feedback. Selling or
  destroying the inspected tower clears it. Pause and outcomes hide feedback.

The panel shows name, upgrade level/size, damage per shot, actual shots per
second, range in cells, next upgrade cost, affordability, or maximum-level status.
Flamma also shows its splash radius; Aqua shows slow strength and duration.

`Arbol.obtener_estadisticas()` reads damage and role properties from the actual
tower and firing rate from its current Timer interval. `mostrar_rango()` draws
the circle from the actual collision shape, including its offset and scale.
The existing base-level `_costo_mejora()` supplies the same price charged by the
upgrade action. Stats therefore reflect upgrades without duplicate UI formulas.

## Wave panel

The lower-right HUD panel displays:

- The next wave before starting, the active wave, or victory/defeat.
- **Restantes:** enemies already on paths plus enemies still waiting to spawn.
- **En camino:** living enemies on all routes, including the Flamma shortcut.
- **Por aparecer / Entrantes:** pending counts grouped by enemy type and size.

Counts refresh every gameplay frame and immediately after wave/spawn events.
The HUD only rebuilds its text when the summary changes. Natura copies count as
new active enemies; their dead source is excluded immediately. Flamma remains
active during revival. Dead, escaped and queued-for-deletion enemies are excluded.
An escaped enemy reduces the remaining count but still damages the mother tree.
Before a wave, incoming counts preview its recipe rather than an empty queue.

`NivelBase._resumen_combate()` constructs the summary from this level's paths and
queue; `hud.actualizar_combate()` formats it. The combat panel blocks board clicks
and drag placement behind it, as the existing top toolbar does.

## Enemy feedback

Each enemy draws a small health bar above its collision body. Green represents
current health, red represents missing health, and the dark border keeps it
readable. Maximum health comes from the enemy's type and size. Damage updates
the bar; Flamma revival restores it to full; final death hides it.

Short labels identify **Lento 40%**, **Detenido**, and **Renaciendo** when relevant.
Labels disappear when their effects expire. All enemy feedback uses the enemy's
existing state, so pausing also freezes the displayed effect state.

## Checks

Run the new suite alongside the existing regression suites:

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_combat_feedback.gd --quit-after 600
```

It covers both levels' wave preview/spawn/copy/escape counts, shortcut death and
revival, health fractions, slow/stun labels and expiration, tower inspection,
upgrade stats/costs, cleanup on sale/pause, HUD bounds and placement blocking.
Player saves are not written. The optional `-- --capture-ui` user argument saves
a rendered preview to `tests/combat_feedback_preview.png` when running with a
real rendering driver rather than headless mode.
