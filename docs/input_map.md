# Gameplay InputMap support

Gameplay now dispatches named InputMap actions rather than checking key numbers
or mouse-button constants. Both levels inherit the implementation in
`scripts/nivel/nivel_base.gd`; their child scripts need no separate input code.

## Actions and fresh-profile defaults

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Casilla Planta 0 ... 6 | F1 ... F7 | Bind directly in settings, or cycle |
| Elemento Natura / Flamma / Aqua / Terra / Electricitas / Glacies / Venenum | 1 / 2 / 3 / 4 / 5 / 6 / 7 | Cycle or bind directly |
| Pala | Q | Left-stick click |
| Iniciar Ronda | Space | Back / Select |
| Alternar Desafio | C | LT |
| Cambiar Prioridad | R | Right-stick click |
| Mejorar Arbol | M | RT |
| Clic Izquierdo | Left mouse | Bind in settings if desired |
| Clic Derecho | Right mouse | Bind in settings if desired |
| Confirmar | Enter | A |
| Atras | Backspace | B |
| Pausa | Escape | Start |
| Izquierda / Derecha / Arriba / Abajo | Arrow keys | Left stick / D-pad |
| Cambiar Casilla Izquierda / Derecha | Bind in settings | LB / RB |
| Alternar Elemento o Planta | Bind in settings | Y |
| Usar Elemento | Bind in settings | X |

The action names are retained even when rebound to a different device. For
example, Clic Izquierdo can be bound to a keyboard key. Mouse type checks now
only choose coordinates or drag behavior; they do not decide which button acts.
Native menu widgets still support normal mouse interaction.

Pala, Iniciar Ronda and Elemento Electricitas were missing from the old action
catalog. They are now in `project.godot` and the configurable-controls list.
Existing saved profiles retain their bindings; newly introduced actions are left
unassigned in those profiles to avoid stealing an already customized key. Bind
them in Options, or use Reset to restore all fresh-profile defaults. Existing
Glacies/Venenum bindings are preserved rather than silently shifted.
The challenge, priority, and upgrade defaults are added to older profiles where their individual bindings are free. Conflicting controls can be assigned under Settings.

## Dispatch and selection

`NivelBase._input()` checks Pausa and cancel actions first, handles directional
cursor use, delegates selection/cycling/wave actions to `hud.manejar_accion()`,
then handles confirmation and drag release. Each handled event is consumed once.
Keyboard echo does not trigger repeated placement, selection, or pause. Exact
matching also keeps modifier bindings such as Ctrl+T distinct from plain T.

The key selection loop in `hud.gd` now follows the action names:

```gdscript
for i in SEMILLAS.size():
    if event.is_action_pressed("Casilla Planta %d" % i, false, true):
        if SEMILLAS_ACTIVAS.has(i) and plantas_disponibles.has(i):
            semilla_pulsada.emit(i, false)
        return true

for i in ATAQUES.size():
    if event.is_action_pressed("Elemento " + ATAQUES[i].nombre, false, true):
        if ATAQUES_ACTIVOS.has(i) and cargas_mostradas[i] > 0:
            ataque_pulsado.emit(i, false)
        return true
```

Plant cycling skips locked and unimplemented scenes. Ability cycling skips locked
and exhausted abilities. Y changes groups; X uses the current ability or selects
the first available ability and uses it. Iniciar Ronda honors the same disabled
state as the HUD button.

## Targeting, confirmation and collection

Mouse movement targets the pointer. Directional actions activate a visible grid
cursor; controller selection/confirmation also activates it. Movement uses
`Input.get_vector()` with InputMap deadzones, bounded grid steps, a 0.3-second
initial repeat delay and a 0.12-second repeat interval. Mouse movement restores
pointer targeting. Placement previews, tower inspection, upgrades, shovel,
abilities and pickups all use the current target.

Confirmar or Clic Izquierdo places/uses the selected tool. With no tool selected,
confirmation selects a planted tower. Mejorar Arbol or the priced upgrade button
buys the next level. The configured
pointer action can select HUD tools and drag them onto the board. HUD panels
block board actions. Pickup collection has priority and consumes the release, so
confirmation cannot both collect and place/cast. A grid cursor collects drops in
the targeted cell, including drops offset from the tile center.

Atras cancels the active tool first, then a pinned inspection, then opens pause.
Clic Derecho clears tools/inspection without opening pause. Pausa always opens
pause directly; the same remapped action closes it.

## HUD hints and menus

HUD labels read current bindings through `ControlesManager.etiqueta_accion()`.
`controles_cambiados` refreshes those hints after saving/resetting controls.
The shovel no longer displays a fixed Q, and abilities no longer assume 1–7.

The controls manager mirrors Confirmar, Atras and the four directional actions to
Godot's `ui_accept`, `ui_cancel` and `ui_*` navigation actions. Native menu buttons,
checkboxes and dialogs therefore honor the same settings. Pause buttons now
accept focus, and victory/defeat menus set an initial focused button. Atras also
returns from settings/save-slot/outcome menus. The pause submenu handles Atras
before returning to gameplay, and opening pause cannot immediately close it with
the same event.

Physical-key conflict detection now compares physical keycodes (and modifiers)
rather than treating different default bindings with `keycode == 0` as equal.

## Verification

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_input_map.gd --quit-after 600
```

This suite changes bindings only in memory and restores them afterward. It checks
both levels, removed/default bindings, remapped keys and mouse buttons, echo
suppression, HUD hints, remapped drag placement, actual joypad confirmation and
selection buttons, cursor deadzones/repeat, group cycling, abilities, wave start,
pickup conflicts, pause remapping and native menu confirmation. It writes neither
player saves nor the user's controls file.
