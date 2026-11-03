# Placement range and well economy

Both features are implemented in the shared level, so they work in level 0 and
level 1 without duplicating child-script logic. Existing saves need no migration.

## Placement preview

Selecting a plant now shows a transparent attack circle centered on its
prospective grid position. The circle and tile are green when placement is valid
and affordable, and red otherwise. Roads, obstacles, existing towers, the mother
tree, the well and out-of-bounds cells remain invalid. The preview hides over HUD
panels and clears when placement is canceled or completed.

`Arbol.obtener_datos_colocacion()` returns the initial attack radius and shape
offset before `_ready()`. The level instantiates the selected scene once to read
those values, then frees the unattached prototype. No firing timers or projectiles
start, and no tower is instantiated per mouse frame. The drawing uses the actual
tile center rather than implying a tower can be placed between cells.

## Well and drops

| Setting | Default |
| --- | --- |
| Well cell | `(28, 5)` in both levels |
| Production | One item every 4 seconds during active waves |
| Currency per collected item | +1 |
| Item lifetime | 20 seconds |
| Uncollected item limit | 5 |
| Initial currency | 3, unchanged |

The former automatic `gotas += 1` time-based income has been removed. Currency
increases through drop collection (and the existing shovel refunds).

The well is a free, preplaced economy object. Its cell is reserved, and the level
validates that it does not overlap roads, the base or obstacles. It uses a simple
drawn well and blue droplet shapes, with no new art assets.

Generation pauses between waves and retains the remaining production interval.
Existing drops can still be collected between waves; their lifetime continues.
SceneTree pause freezes production and expiration and blocks collection. Victory
and defeat stop production and block collection. Reloading a level resets its
well and transient drops along with the rest of the board.

The five positions around the well are reused after collection or expiration.
When all positions are occupied, production skips that tick rather than adding
more objects or awarding automatic income. Expired items grant nothing.

## Wiring

```text
NivelBase
  pozo_escena -> res://escenas/escenas_economia/pozo.tscn
  celda_pozo -> configurable on the child scene root

Pozo (Node2D, scripts/economia/pozo.gd)
  Temporizador (Timer)
  Gotas (Node2D)
    Gota (instances of escenas/escenas_economia/gota.tscn)
      Expiracion (Timer)
```

The parent supplies `puede_generar` and `puede_recoger` Callables. Each drop's
`recogida(cantidad)` signal goes to the well; the well emits
`gota_recogida(cantidad)` to `NivelBase._recoger_gotas()`, which updates currency
and HUD affordability. Collected/expired flags prevent duplicate awards before
deferred deletion completes.

`NivelBase._input()` checks `_recoger_en_objetivo()` before placement, upgrades or
abilities. It consumes the collection press and release, so the same action cannot also plant
a tower or cast a spell. The configured Clic Izquierdo / Confirmar actions also
collect drops; a controller cursor can collect a drop anywhere in its grid cell.
Releasing a dragged plant over a drop collects the drop
instead. The current tool stays selected for the next board action. HUD panels
retain priority over world pickups.

Tune production interval, value, lifetime and item cap on `pozo.tscn`'s root.
Tune `celda_pozo` and optionally `pozo_escena` on an inherited level root. Drop
expiry and production use Timer nodes that inherit the level's pause mode.

## Validation

```powershell
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/test_well_economy.gd --quit-after 600
```

Checks cover both levels, generation without automatic currency, actual input
dispatch while planting/casting/dragging, single collection, HUD updates, cap and
expiration, pause, collection between waves, terminal states, and agreement
between preview radius/offset and the placed tower. Existing regression suites
also remain applicable; shared-level tests now expect manual collection income.
