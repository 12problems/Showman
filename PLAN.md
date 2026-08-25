# Showman: what's left

This is a working plan for the mod's outstanding work, written to be picked up cold - each
item includes enough of the "why" and "where" to act on without re-deriving it. See
`README.md` for the user-facing summary; this is the implementation-level version.

## Done so far

- Base shop/joker search (Analyze button, ante + search-depth controls, paged results).
- Skip Tags, Boss, and Packs prediction, surfaced together in a "Shop Preview" queue option
  that takes over the results area for a chosen ante: Boss + Skip Tags icons, then all 3 shop
  visits' worth of packs (2 slots each - see the note on packs below), with a hover popup
  showing each pack's predicted contents.
- `Showman.RNG.detect_ante_suffix()` (`Showman_seek.lua`): auto-detects whether the running
  game's pool-key formula folds the current ante into its random-seed key. This varies between
  a pure-vanilla game and the Steamodded-patched game almost everyone actually runs - vanilla
  doesn't, Steamodded does. Detected by directly probing the live `get_current_pool` global
  function rather than checking "is SMODS loaded", so it tracks whatever the actual running
  game does rather than assuming. Manual override available as "Seed Format" (Auto/Modded/
  Vanilla) in the Showman tab, for the rare case the probe is ever wrong.

## 1. Fix core Shop/Rare Queue/Wraith-Rare Skip/Judgement/Spectral/Tarot prediction accuracy

**Priority: highest - this is the mod's main feature, and it's currently wrong.**

Live-tested (predict N items ahead with `generateWithOptions`, then actually play a real seeded
run forward and diff against the real `G.shop_jokers`/`G.shop_vouchers` contents) and confirmed
the "Shop" queue's predictions don't match the real game for a fresh run. Not root-caused yet.

Where to start:
- The generation path is `create_pseudocard_for_options` (`Showman_seek.lua`) ->
  `Showman.FUNC.create_card` -> `Showman.FUNC.pick_from_pool` -> `Showman.FUNC.get_current_pool`.
- The Skip Tags fix this project already went through (see git log around the "Seed Format"/RNG
  detection work) is a plausible template: that bug was an ante-suffix formula mismatch between
  vanilla and the actually-installed Steamodded build, only caught by comparing live predictions
  against real captured game state rather than reading source alone. The shop/joker path might
  have a similar or related mismatch (key format, rarity-roll formula, something in the eternal/
  perishable/rental sticker rolls, edition polling order, etc.) - or it might be something else
  entirely. Don't assume it's the same bug; re-derive it the same way: predict, then actually
  play, then diff.
- A real Balatro instance is needed to test against - this can't be verified by reading source.
  If you have a way to drive/observe a running instance programmatically (this project used one
  during the Skip Tags work), predict-then-play-forward-and-diff is much faster than manual
  clicking; otherwise, manual seeded-run testing works too, just slower per iteration.
- Test at least the "Shop" queue at ante 1 and ante 2+ with a fixed seed, several times, before
  concluding a fix is correct - both because there may be more than one bug, and because a fix
  that only happens to work for the specific case you first tried is not a fix.

## 2. Voucher prediction

Not implemented at all yet - no dedicated queue option, no `generateVoucherForAnte`-style
function. This is the one piece of the original "shop packs, vouchers, etc" plan not yet built
(packs are done).

- `Showman.FUNC.get_current_pool` already has a working `Voucher` branch (see the `v.set ==
  'Voucher'` case in its cull loop) - the pool-eligibility logic already exists and is already
  exercised by other code paths, it just isn't wired up to its own predictable "which voucher(s)
  show up at ante N" output yet.
- Real vanilla/Steamodded's `get_next_voucher_key()` calls `get_current_pool('Voucher')` with no
  append - under the ante-suffix-detected build this project actually runs, that key ends up
  ante-suffixed the same way Tags/Bosses/Packs were found to be (or not - confirm this
  empirically the same way the RNG model work did, don't assume it matches Tags just because the
  call shape looks similar).
- Natural home for this in the UI is probably alongside Boss/Skip Tags in "Shop Preview" (one
  voucher per ante, similar to the Boss slot) rather than a whole separate queue option - but
  that's a design call, not a given; check with whoever's asking for it if it's not obvious.

## 3. "Deck Order" view

Not started. This is a live read of the *actual current* deck shuffle order, not a prediction -
no RNG replication needed at all, which makes it simpler than everything else in this file.

- Real deck order comes from `CardArea:shuffle(seed)` (`cardarea.lua`), called with seeds like
  `'nr'..ante` (new round) and `'cashout'..ante` (leaving the shop) - by the time a player would
  want to look at this, the shuffle has already happened for real; this is just reading
  `G.playing_cards` filtered to cards currently in the deck, in their real current order.
- Hook point: `G.UIDEF.deck_info` builds the "Remaining"/"Full Deck" tabs shown when a player
  clicks their deck, via `create_tabs`. Showman already wraps `create_tabs` once (gated on
  `args.tab_h == 7.05`, for its own settings tab) - this would be a second wrap, gated on
  detecting *this* specific `create_tabs` call instead (an id/tab_definition_function check on
  the deck-info tabs specifically, since `tab_h == 8` alone isn't unique to it), appending a
  third "Deck Order" tab.
- Render real `Card` objects (they already carry their real edition/enhancement/seal) via an
  ordinary `CardArea`, same pattern as everywhere else in this mod - no synthetic center lookup
  needed, which is unusual for this mod (everything else has to reconstruct predicted state from
  scratch; this is the one feature that gets to just read it).
- Open question, not resolved: mid-round, does "deck order" mean the full deck's shuffle-position
  order, or just the undrawn remainder in draw order? Decide this before building, not during.

## 4. Minor: Steamodded's "modded legendary consumables" extension isn't replicated

Real `create_card`'s Soul/Black Hole forcing (in the installed Steamodded build) has an extra
block for *other* mods' custom Soul-like legendary consumables (`SMODS.Consumable.legendaries`,
a `'soul_smods_'..type..ante` roll) that `Showman.FUNC.resolve_forced_key` (`Showman_seek.lua`)
doesn't replicate. Zero practical effect with no such mods installed, so this is low priority -
but if a modpack that adds one of those ever gets used with Showman, predictions involving Soul/
Black Hole forcing for that ante would be wrong until this is added.

## How to verify any of this

Static reading of the source has repeatedly turned out to be insufficient for this mod - the
Skip Tags and RNG-model work both went through a "this looks right from the code" stage that
turned out to be wrong, caught only by comparing predictions against a real running game. Budget
for that when picking up anything in this file: predict, then actually reach that point in a
real seeded run, then diff. Don't ship a fix on code-reading confidence alone.
