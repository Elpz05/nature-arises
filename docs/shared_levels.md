> Actualización: la campaña tiene ahora ocho niveles y guardado v2. Véase [campana.md](campana.md) para progresión, migración y validación actuales.

> Para la economía actual, véase [Pozo y vista previa de plantado](well_economy.md).

# Shared level structure

Both playable scenes now inherit `res://escenas/escenas_niveles/nivel_base.tscn`.
Their scripts inherit `res://scripts/nivel/nivel_base.gd` (`class_name NivelBase`).
The existing playable scene paths and UIDs remain in place, so the campaign and
save manager keep loading the same files.

```text
nivel_base.tscn + nivel_base.gd
  Suelo          TileMapLayer
  Camino         TileMapLayer
  RutaEspiritu   Path2D
  Arboles        Node2D

nivel_0.tscn + nivel.gd       inherits the base scene/script
nivel_1.tscn + nivel_1.gd     inherits the base scene/script, adds Atajo
```

The base scene is a template, not a standalone playable map. Play level 0 or 1.

## Responsibilities

| Owner | Responsibility |
| --- | --- |
| `nivel_base.gd` | Grid generation, road/obstacle occupancy, route construction, enemy spawning/copy connections, wave start/completion, income, abilities, placement, upgrades, refunds, previews, HUD, pause, victory and defeat |
| `nivel.gd` | Level 0 route, mother-tree cell, wave recipes, music |
| `nivel_1.gd` | Level 1 route, mother-tree cell, mixed wave recipes, Flamma shortcut description |
| Child `.tscn` files | TileSets, enemy/tower/HUD/outcome scene assignments, level index, optional obstacle cells and spawn intervals |

## Child configuration hook

The parent calls `_configurar_nivel()` at the beginning of its `_ready()`, then
validates the configuration and builds the board and HUD. Children do not need
their own `_ready()`, `_process()`, input handlers, or `super._ready()` calls.

Level 0 uses:

```gdscript
extends "res://scripts/nivel/nivel_base.gd"

# RUTA, CELDA_ARBOL_MADRE and RONDAS are the level's constant data.
func _configurar_nivel() -> void:
    puntos_ruta = RUTA
    celda_arbol_madre = CELDA_ARBOL_MADRE
    rondas = RONDAS
    musica_nivel = preload("res://audios/nivel_musica/Forest 03.ogg")
```

Both levels now use the same recipe keys: `tipo:tamano`, for example:

```gdscript
const RONDAS := [
    {"natura:pequeno": 4, "flamma:pequeno": 2},
]
```

The number of waves is derived from `rondas.size()`. The Inspector's
`intervalos_spawn` array supplies the corresponding spawn delays; provide one
positive delay per wave when adding waves.

## Alternate routes and obstacles

For each shortcut, supply the enemy type, entry and exit waypoints, and a marker color. Intermediate exits are optional.

```gdscript
rutas_adicionales = [
    {"tipo": "flamma", "tramo": [Vector2i(26, 7), Vector2i(26, 13)],
        "salidas": [Vector2i(26, 10)], "color": Color.ORANGE},
]
```

The parent builds the route from the main path's prefix and suffix, paints the branch on the child's `Atajo` TileMapLayer, and adds directional markers. Fork and merge cells must be on the main path in travel order, and the branch must shorten it. Grass towers cannot occupy the branch, while Terra can block it. Enemies transfer back at the merge, preserving their remaining movement. The Aqua spell can use a declared intermediate exit while confusion is active. Crossings alone do not create exits. Enemy counts include every route.

For non-road obstacles, set the inherited `celdas_bloqueadas` array on the child
scene root. The parent reserves these cells without creating art or geometry.
Routes must consist of horizontal/vertical segments, with at least two points.

Campaign layouts live in `TERRENOS` in `scripts/nivel/campana.gd`, in level order. Each map defines its dry plots, optional Terra posts on dry road or shortcut cells, and optional Aqua sites. The shared level validates these coordinates against the route, weather, and reserved infrastructure. Dry plots can also hold Terra when a blockade off the road makes sense, such as shielding a column in the collapse stage. For standalone scenes, configure the inherited `limitar_plantado`, `parcelas_secano`, `puestos_terra`, and `celdas_inundadas` exports. The mechanics lab leaves the plot restriction off.

Enemy scenes retain the existing assignments: level 0's `espiritu_escena` is its
Natura fallback; level 1's `bestias_escenas` uses Natura/Flamma/Aqua order. The
parent owns both lookup paths and the standardized copy signal connection.

## State and behavior

`_puede_jugar()` centralizes the initialized / not paused / not finished check.
It protects frame updates, wave starts, selection, placement, upgrades, refunds,
abilities and spawning. Pause uses SceneTree pause as before; outcome handlers
clear selection and pending spawns, set `terminado`, and pause the tree.
Repeated victory/defeat calls cannot create duplicate overlays.

Existing costs, tower roles, manual wave starts, ability recharge,
unlock IDs and wave compositions are preserved. This refactor does not change
the tower definitions or consolidate HUD/scene costs; that can be a later pass.

See [the well economy](well_economy.md) for production and collection. The HUD uses the top three reserved grid rows for combat information, actions, and tower inspection.

## Adding a level

1. Create a scene inherited from `nivel_base.tscn`.
2. Attach a script extending `nivel_base.gd`, implementing `_configurar_nivel()`
   with its route, base cell and recipes.
3. Assign the map TileSets and inherited scene exports. Add the `Atajo` layer
   for levels with `rutas_adicionales`. Set obstacle cells as needed.
4. Set `numero_nivel`, unlocks and spawn intervals on the child scene root.
5. Register the playable scene in `Guardado.NIVELES`.

## Validation

Run with Godot 4.7.2 from the project directory:

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_shared_levels.gd --quit-after 600
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_tower_roles.gd --quit-after 600
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_critical_fixes.gd --quit-after 600
```

The shared-level suite checks both inherited scenes, grid/road/obstacle blocking,
shortcut routing and wave completion, all five wave counts, income, HUD wave
signals, ability charges/recharge, pause/resume, victory, defeat, and terminal
state guards. Tests avoid writing player saves.
