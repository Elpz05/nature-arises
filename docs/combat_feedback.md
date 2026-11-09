> Actualización: las reglas de economía, pala, Flamma y Aqua de este documento han sido sustituidas por [el primer bloque de mecánicas](mecanicas_implementacion.md).

# Combat information

Combat feedback runs in the shared level, HUD, tower and enemy scripts across
the campaign. The board uses existing fonts and simple shapes.

## Tower inspection

- The number and health bar under each tree show its current level and HP
  fraction. Low HP turns the bar amber, then red.
- Click or confirm on a tree to pin its range and compact card, even with debug
  off. The card shows exact HP, key stats, and the priced **Mejorar** button.
  Click it or use the configured **Mejorar Arbol** action (**M** or the right
  trigger by default). The selection stays pinned after an upgrade.
- The button disables at maximum level or when the player lacks water. The card
  stays inside the viewport and avoids the central well. Starting another tool,
  confirming an empty cell, or canceling clears selection.
- The debug dock adds detailed stats on hover. Pausing hides the card and range.
  Returning to the board restores the selection if its tower is still present.

Rejected planting attempts briefly show a reason beside the target. The
selected seed stays available for another attempt.

`Arbol.obtener_estadisticas()` reads damage and role properties from the actual
tower and firing rate from its current Timer interval. `mostrar_rango()` draws
the circle from the actual collision shape, including its offset and scale.
The existing base-level `_costo_mejora()` supplies the same price charged by the
upgrade action. Stats therefore reflect upgrades without duplicate UI formulas.

## Wave panel

The debug HUD displays the following wave information.

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

Shape icons above units identify auras and active effects. The orange shield
shows Flamma's cold protection, the blue shield shows Aqua's radiation
protection, and the bolt shows exposure to Electricitas. **Guía de campo →
Cómo jugar** explains the same symbols used on the board. Their colors and
shapes live in \`scripts/HUD/iconos_combate.gd\` for easy replacement.

**Ajustes → Números de daño** controls floating numbers independently of debug
mode and is on by default. The number shows actual HP lost after modifiers,
immunity and overkill. Rapid hits on the same target and fractional damage over
time are grouped to keep the feedback readable.

## Checks

Run the new suite alongside the existing regression suites:

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_combat_feedback.gd --quit-after 600
```

It covers both levels' wave preview/spawn/copy/escape counts, shortcut death and
revival, health fractions, slow/stun state and expiration, tower inspection,
upgrade stats/costs, cleanup on sale/pause, HUD bounds and placement blocking.
Player saves are not written. The optional `-- --capture-ui` user argument saves
a rendered preview to `tests/combat_feedback_preview.png` when running with a
real rendering driver rather than headless mode.

\`tests/test_ux_combate.gd\` checks normal HUD selection, the nearby upgrade
button, status transitions, placement feedback, damage grouping, and settings
persistence.
