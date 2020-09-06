This mod adds on/off switch button for sending a single circuit network signal.

Note that button is reachable from anywhere on the map, and can be toggled by left-click or player inventory key (E) by default, but it can be changed to work more like regular constant combinator via mod settings.

Mod Settings (startup):

- Toggle On/Off on click [default: checked]

    **Checked**: Will change On/Off state on left-click or player inventory key (E), will open signal panel with the assigned keybind.
    **Unchecked**: Left-click will work normally like with a regular constant combinator, hotkey (default F) will toggle On/Off state.

- Show signal in Alt-info mode [default: checked]

    **Checked**: Display configured signal overlay when switch is enabled in Alt-info mode, like constant combinator does.
    **Unchecked**: Do not display signal in Alt-info mode.

- Button reach range [default: 99999 - unlimited]

    Range from which switch buttons can be toggled. Will automatically fall back to default player's reach if set to a lower value (e.g. 0).
    Default is 99999 (from anywhere on the map), set to 0 to have same reach as with any other combinator.

Mod hotkey - "Switch Button keybind" - allows to either open switch inventory or to toggle it, depending on "Toggle On/Off on click" mod option described above.

Based on [the original Switch_Button mod](https://mods.factorio.com/mod/Switch_Button) by GalactusX31, with some minor bugfixes and updated for compatibility with Factorio 1.0.
