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

## Does it work with blueprints?

It should, as of 0.0.69, but only stores combinator code there, as other state is likely specific to the original setup.

There is one known issue however - "select new contents" button in an open blueprint window will not store the code due to known Factorio API problem/limitation (see "Known Issues" section in the main mod description for more details), which might be fixed in the future though, and then that button should "just work".

----------

## Make lua code that updates lua code

There is `ota_update_from_uid` value, which you can use with centralized "reference combinators" somewhere or set from any kind of wireless signals (see any of the "wireless network" mods for more options there).

You can use secret "_api" value within sandbox environment to implement something more complicated, but I think that's outside the purpose of this mod and game mechanics - see ["further ota update suggestions" thread](https://mods.factorio.com/mod/Moon_Logic/discussion/5f5c7a5f2348f529f9d07a92) for more details.

----------

## Using many combinators from this mod or running a lot of code on those makes game slow

For most simple tasks, I'd suggest using stock signal combinators instead - they are very fast, can do a lot already, and it's fun to build logic out of them.
Maybe simply replacing multiple Moon Logic combinators with one is an option? Wire signals can be aggregated and translated using arithmetic combinators.

Then there's a "delay" value, which can often be set to something really high, as it's rare that lua combinator code needs to run on every single game tick.
Note that it doesn't have to be constant, and only sets delay until the next run.
Using "irq" value on these combinators is another way to simply run stuff less often, and only when needed.

When there's just too much code, it can also be benchmarked using e.g. `/measured-command remote.call('mlc', 'run', 1234, 1000)` [console command](https://wiki.factorio.com/Console#Scripting_and_cheat_commands), which will run code on uid=1234 combinator 1000 times (default is to run code once, if last number is not specified) and print precise time that it took to run it.
Should be possible to isolate slow parts of the code this way, and either optimize or run them less often too.

Factorio's built-in [Debug Mode](https://wiki.factorio.com/Debug_mode) can also be used to identify performance issues with mods in general, especially if it's unclear which mod might be the problem.

----------

## Access full factorio modding API and things like prototype parameters there

There's an undocumented and DANGEROUS "_api" value - see ["Can I somehow import code form other lua-controllers?"](https://mods.factorio.com/mod/Moon_Logic/discussion/5fd812fd203f61023cd1fba0) or ["Access item information"](https://mods.factorio.com/mod/Moon_Logic/discussion/5f55071254dbb0ecb39e6908) threads for a basic gist of it. That hack provides access to most of the factorio modding api, which is well-documented at https://lua-api.factorio.com/latest/

You can easily break your game and saves in many ways when using that, so I'd suggest not touching it unless you know what you're doing and is ok with that.
Also anything that looks like a mod bugs happening after that might be entirely due to using things there.
