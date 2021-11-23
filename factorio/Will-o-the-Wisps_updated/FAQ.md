--------------------

## LuaRemote interfaces - for other mods and mod developers

Any of these interfaces can be used to interact with mechanics of this mod from other mods at any time.

Checks are made to ensure that this mod was initialized when they're called (i.e. if it's done before first game tick), and that all passed entities are valid, as otherwise call shouldn't be relevant anyway and will be ignored. Various numeric value ranges are not checked though, so maybe clamp those before passing through from other calculations.

These interfaces are probably not well-tested, but relatively simple wrappers for mod internals used elsewhere, so should hopefully be relatively bug-free anyway, and any issues should likely be immediately apparent when making the call.

- `wisps.uv` - interface to control anti-wisp UV lights mechanics.

    - `emit_start(entity [,range, [, energy_high [, energy_low]]])`

        Registers entity as a standard UV-lamp, like ones in this mod, to repel wisps.

        Effective range value (in tiles) is optional, and will default to UV lamp ranges in this mod, configurable via mod settings.
        Optional energy high/low limits are compared to entity.energy value, if specified, and if it's between these, then effectiveness is reduced in a linear fashion - i.e. in the middle = 50%.
        If neither limit is specified, effectiveness is always 1 (100%) and entity.energy is not checked in any way.
        If only energy_high is specified, energy_low defaults to 0.

        There should be no need to call anything else for new/modded UV lamps - just register them via this call when built/created (with optional energy bounds), and if they later get destroyed/removed/invalid, they'll get auto-cleaned-up from tracking in this mod.

        Do not use this call multiple times on the same entity - use emit_stop() + emit_start() to change range/energy values.
        &nbsp;

    - `emit_stop(entity_or_unit_number)`

        Unregister entity or unit_number (as in entity.unit_number) from known UV-light sources.

        This does not need to be called for removed or destroyed entities, as they're "forgotten" by this mod automatically, only if you want for existing in-game entities to stop having this effect.
        &nbsp;

    - `emit_once(entity [, range [, effectiveness]])`

        Make wisps flee from UV light source and cause damage to them, in exactly same way as UV lamps in this mod do. Range defaults to UV lamps in the mod (configurable), and effectiveness to 1.0 (=100%).

        Can be used to make a custom UV-emitting effect on wisps in this mod, i.e. add this to a weapon, ammunition, any kind of event, etc. Should be easier to use emit_start() for just custom lamps.
        &nbsp;

- `wisps.control` - misc interfaces to interact with wisp entities from this mod.

    - `get_entity_names()`

        Returns a simple list/table like `{'wisp-red', 'wisp-yellow', 'wisp-green', ...}` with names of all entities currently used by this mod.
        &nbsp;

    - `find_units(surface, position, range)`

        Returns list/table of unit-like wisp entities in a range around specified position.
        &nbsp;

    - `find_spores(surface, position, range)`

        Returns list/table of purple wisps in a range around specified position.
        Separate from find_units() because these have somewhat different properties from red/yellow/green wisps, i.e. can't be controlled like units, don't have normal attack, cannot be targetted with weapons, etc.
        &nbsp;

    - `create(name, surface, position[, angry[, ttl]])`

        Create a wisp with a specified name (e.g. from get_entity_names() list) at or near specified position.

        Any non-nil value for optional "angry" argument will spawn a hostile wisp, if these are allowed by the mod settings.
        "ttl" - time to live - is a time in factorio ticks after which wisp will disappear on its own, and defaults to a slightly-randomized value specific to each wisp type.
        &nbsp;

Random usage examples:

- `remote.call('wisps.uv', 'emit_start', my_mod_entity)`
- `remote.call('wisps.control', 'create', 'wisp-yellow', player.surface, player.position)`
