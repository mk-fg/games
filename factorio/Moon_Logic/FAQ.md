**Note: information here might get outdated, please report if you notice that somewhere.**

----------

## Game gets laggy (aka low UPS) when I open Moon Logic Combinator connected to a logistic network

By default, mod updates input/output signals tab in the opened combinator GUI on every tick (60 times a second), so that any signals flapping their value back-and-forth can be easily visible there.

Set "GUI Signals Update Interval" option to a higher value for better performance, but with that caveat of potentially making quick changes undetectable.
Use prime number values there (not divisible into parts) to make sure that at least any cyclical changes will be unlikely to hide neatly within such interval.

----------

## "red.wood" works, but "red.fast-transport-belt" shows some lua error on the combinator

"-" is an arithmetic minus operator in lua code, so `red.fast-transport-belt` is same as `red.fast - transport - belt`, i.e. `red.fast` value minus `transport` value minus `belt` value, resulting in something like a `Unknown signal name "fast"` error shown at the bottom of the combinator window.

`<table>.<key-literal>` in lua is just a convenience shorthand for `<table>[<key-value>]`, so use the latter form instead, e.g. `out['fast-transport-belt']` or `red['express-transport-belt']`.

----------

## What's up with that multiplayer support?

As mentioned in the description, I don't play MP myself, and given the nature of what this mod does internally (e.g. uses code objects that can't be serialized in globals), it's easy to break and is likely to be broken, unless tested for desyncs after any kind of major changes, which I can't really do easily.

So it's unlikely to be added, and best way to maintain it for anyone interested - that I can think of - is probably to make a separate multiplayer-friendly copy/version of this mod, test and fix any issues there, and then either merge changes one way after proper testing, or maybe also merge them back here if they don't make internals too complicated, purely for easier syncing between the two in the future.

Anyone who knows lua and has time/patience to test multiplayer should be able to do it, there's even no need to ask for permission or anything, feel free to!
(make sure to remove "_api" value from sandboxing to prevent players from cheating there btw)

----------

## Syntax highlighting, auto-indentation and other modern text editor features would be nice

It's just too complicated to implement and maintain for me, especially given restrictions of a factorio GUI system.

And on top of that, text editing lag resulting from it feels completely unbearable to me (try linked earlier lua combinator mods).
I'd suggest even disabling existing "undo" feature ("Enable Code Editing History" mod option) to make editing text within that GUI more tolerable.

Just tab-out to a Notepad++, Vim, Emacs or any out-of-game text editor for >10 lines of code and edit it there.

----------

## Using out.somesignal picks that signal of a wrong type (item, fluid, virtual)

When you specify e.g. "signal-A", it will be matched for first type in this order: virtual, fluid, item.

Using same-name signals with different types is not supported, but if there's a legit use-case for it, maybe leave a comment somewhere, and see also ["Same signal names with diff type in Attach Notes mod" thread](https://mods.factorio.com/mod/Moon_Logic/discussion/601dc6dd84b410248ac51690) about it.

I'm not aware of any mod creating such duplicate signal names atm.
[Attach Notes](https://mods.factorio.com/mod/attach-notes) technically does it, but only with hidden items, which are not exposed as selectable circuit network signals anyway.

----------

## Saving lua code in blueprints

Difficult and rather inconvenient to make it work.

It can be done by placing some extra invisible constant combinators into the blueprint and serializing text into their settings, and there are third-party libraries to do that, but that's complicated, not great for potentially-large code sizes, shows up in-game and has other drawbacks.

Currently code is copied from blueprint source moon-logic-combinator for easy Ctrl+C/Ctrl+V, and preset buttons can be used to same effect.
For copying/editing large chunks of code between games, I'd suggest using a nice out-of-game text editor and a text file (maybe in a proper repository too).

----------

## Make lua code that updates lua code

There is `ota_update_from_uid` value, which you can use with centralized "reference combinators" somewhere or set from any kind of wireless signals (see any of the "wireless network" mods for more options there).

You can use secret "_api" value within sandbox environment to implement something more complicated, but I think that's outside the purpose of this mod and game mechanics - see ["further ota update suggestions" thread](https://mods.factorio.com/mod/Moon_Logic/discussion/5f5c7a5f2348f529f9d07a92) for more details.

----------

## Access full factorio modding API and things like prototype parameters there

There's an undocumented and DANGEROUS "_api" value - see ["Can I somehow import code form other lua-controllers?"](https://mods.factorio.com/mod/Moon_Logic/discussion/5fd812fd203f61023cd1fba0) or ["Access item information"](https://mods.factorio.com/mod/Moon_Logic/discussion/5f55071254dbb0ecb39e6908) threads for a basic gist of it. That hack provides access to most of the factorio modding api, which is well-documented at https://lua-api.factorio.com/latest/

You can easily break your game and saves in many ways when using that, so I'd suggest not touching it unless you know what you're doing and is ok with that.
Also anything that looks like a mod bugs happening after that might be entirely due to using things there.
