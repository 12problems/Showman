# Showman
A mod for Balatro that allows for seed analysis to be performed in-game.

You simply open the Settings, go to the Showman tab, and choose which ante you would like to check the shop for, how far into the shop you want to search, and if the analysis should perform as if you have the Showman joker (regardless if you own it at the moment, just so you can see repeats for the sake of owning a Showman).

This mod was inspired by the tool The Soul (https://spectralpack.github.io/TheSoul/). I like this tool for preparing seeded runs; however, it not being in game can be a pain, and the UI is not super user friendly to searching deep into the shop for multiple things.

Current plans:

- ~~Make base functionality work~~ done
  - ~~Fix bug where page buttons don't update when they should~~ done
- Add support to find and track (pin to main UI?) jokers in the shop.
- ~~Add support for shop packs, vouchers, etc~~
  - Shop packs: done - a "Shop Preview" queue option shows Skip Tags, the Boss, and all 3 shops' worth of packs for a chosen ante at once, with a hover preview of each pack's predicted contents.
  - Vouchers: not done yet.
  - ~~Maybe find a way to view results of skip tag jokers?~~ done, same Shop Preview view.
- Clean up code :)

Still to do, roughly in priority order:

1. **Fix the core Shop/Rare Queue/Wraith-Rare Skip/Judgement/Spectral/Tarot prediction** - this is the mod's main feature, and it's currently predicting results that don't match the real game when checked live. Needs a dedicated investigation, not a quick patch.
2. Voucher prediction - the last piece of the original "shop packs, vouchers, etc" plan; not implemented yet.
3. A "Deck Order" view - showing the *real* current deck shuffle order (not a prediction, a live read) inside the game's own deck-view screen. Designed, not built.
4. Minor: Showman now auto-detects whether the running game's seed formula folds the ante into its pool keys ("Seed Format: Auto/Modded/Vanilla" in the Showman tab), which covers vanilla and the Steamodded-patched game. It doesn't yet replicate Steamodded's own hooks for *other* mods that register custom RNG-affecting content (e.g. a mod adding its own Soul-like legendary card) - low priority unless you're running mods like that.


I want to thank Balatro University for being a partial inspiration for me making this mod, and for all of the great content he puts out. Without you, Doc, I would not have the same love for this game that I do. 

Also a special thanks to the creators of the Brainstorm mod which was heavily influencial as source material for both creating a mod from scratch and touching RNG elements.



INSTRUCTIONS:

In the Options menu, you can find the tab for the Showman mod. 

Choose which ante you want to view, how many shop items you want to list, and click the "Analyze" button. You can flip through the pages and see all of the items which will appear in the shop.

Choosing "Apply Showmman?" simulates if you have the Showman joker, in case you're trying to predict duplicates of the same kind you already have. 

Pick "Shop Preview" from the Queue selector instead of a specific search to see that ante's Skip Tags, Boss, and all 3 shops' worth of Packs at a glance - hover a pack to see its predicted contents.

"Seed Format" should be left on "Auto" - it detects whether the game you're running needs its seed formula adjusted (this varies between vanilla and modded installs) and only needs to be changed by hand if that ever guesses wrong.
