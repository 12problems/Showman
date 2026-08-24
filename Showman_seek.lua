Showman.SEEK = {}
Showman.SEEK.GAME = {}
Showman.SEEK.GAME.pseudorandom = {}
Showman.SEEK.GAME.pseudorandom.seed = 0
Showman.SEEK.GAME.pseudorandom.hashed_seed = 0

-- Resolves which ante to generate against: the user-selected ante, unless an
-- external strategy overrides it via Showman.FUNC.ante_override_hook (set by
-- Showman_order.lua to force ante 0 while The Order is active, matching the real
-- game's ante-zeroing for card RNG - The Order is the only thing that does this;
-- normal single-player prediction needs the actual selected ante).
local function resolve_search_ante()
    local ante = Showman.config.SEEK.search_ante or 1
    if Showman.FUNC.ante_override_hook then
        ante = Showman.FUNC.ante_override_hook(ante)
    end
    return ante
end

function generateWithOptions(count, queue)
    Showman.SEEK.ANTE = {}

	Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
	Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
	Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed
    local ante = resolve_search_ante()
    output = ""
    cards = {}
    editions = {}
    stickers = {}
    for i=0,count-1 do
        c, e, s, k = create_pseudocard_for_options(ante, Showman.config.SEEK.search_queue)
        if output ~= "" then output = output..", " end
        cards[i] = k
        editions[i] = e
        stickers[i] = s
        if e == "" or e == nil then
            output = output..(c)
        elseif e == "Negative" then
            output = output.."** Negative **"..(c)
        else
            output = output..(e).." "..(c)
        end
    end
    Showman.SEEK.ANTE[1] = cards
	return output, cards, editions, stickers
end

function generateShopUntil(joker_name)
	Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
	Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
	Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed
    local ante = resolve_search_ante()

	c = ""
	e = ""
	count = 0
	output = ""
	cards = {}
	while c ~= joker_name and count < Showman.config.SEEK.search_depth do
		c, e = create_pseudocard_for_options(ante, Showman.config.SEEK.search_queue)
		cards[count] = e and (e.." "..c) or c
		if output ~= "" then output = output..", " end
		if(e == "" or e == nil) then
			output = output..(c)
		else
			output = output..(e).." "..(c)
		end
		count = count + 1
	end
	if count >= 1000 then
		--sendDebugMessage("Could not find "..joker_name.." in "..count.." items!")
	else
		--sendDebugMessage("Search for "..joker_name.." - Found after "..count.." items! > "..output)
	end

	return output, cards
end

-- === Shared pool-pick helper (resample-loop boilerplate used by several
-- generators below). ===
local function pseudorandom_pool_pick(_pool, _pool_key)
    local picked = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key))
    local it = 1
    while picked == 'UNAVAILABLE' do
        it = it + 1
        picked = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key..'_resample'..it))
    end
    return picked
end

-- === Skip Tags (always-visible per-ante side panel) ===
--
-- IMPORTANT, confirmed against the actually-installed Steamodded build (its
-- lovely-patched functions/common_events.lua, not pure vanilla BalatroSource):
-- Steamodded's own get_current_pool unconditionally ante-suffixes the pool key
-- it returns with the LIVE G.GAME.round_resets.ante (`return _pool, _pool_key
-- ..(not _legendary and G.GAME.round_resets.ante or '')`) - vanilla itself
-- doesn't do this, but the installed SMODS build does, and that's what's
-- actually running. So get_next_tag_key's pool key really is "Tag"..ante (e.g.
-- "Tag1", "Tag2", ...), independently keyed per ante - directly predictable by
-- formula for any future ante, same as shop/pack cards, NOT a single
-- continuously-advancing chain (an earlier pass through this file assumed pure
-- vanilla's un-suffixed "Tag" key and was wrong - caught by live A/B testing
-- via the ClaudeControl testing mod: predicted ante-2 tags with the un-suffixed
-- key, then actually played to ante 2 for real and compared).
--
-- Two-call quirk still holds though: vanilla calls get_next_tag_key() twice per
-- ante transition with no distinguishing argument (Small then Big) - since
-- Showman.FUNC.pseudoseed auto-advances its per-key chain on every call, two
-- calls in a row for the same ante key naturally reproduce that.
function create_pseudotag_for_ante(ante)
    local _pool, _pool_key = Showman.FUNC.get_current_pool('Tag', nil, nil, nil, ante)
    return pseudorandom_pool_pick(_pool, _pool_key)
end

-- Generates Small/Big skip tags for `target_ante`. The real CURRENT ante's pair
-- is already decided and visible - read it straight off
-- G.GAME.round_resets.blind_tags rather than reformulate, since by the time
-- Showman can query it, "Tag"..real_ante's chain has already been advanced by
-- the real roll and a fresh formula call would silently compute the position
-- *after* that (wrong). A past ante (real_ante has already moved beyond
-- target_ante) is genuinely unrecoverable the same way - returns nil. Any
-- future ante's key hasn't been touched yet in the real G.GAME.pseudorandom
-- table, so a direct formula call from a fresh snapshot is exact - re-seeded
-- fresh every call (same as generateWithOptions/generateShopUntil) so this is a
-- pure function of (target_ante, real game state) with no cache to keep in
-- sync. "Sometimes more than 2" (a rolled Double Tag grants another tag
-- immediately) isn't chased here - always exactly Small + Big.
function generateSkipTagsForAnte(target_ante)
    local real_ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    if target_ante == real_ante then
        local bt = G.GAME.round_resets.blind_tags
        if not bt then return nil end
        return { Small = bt.Small, Big = bt.Big }
    elseif target_ante < real_ante then
        return nil -- already rerolled past this point for real; not recoverable
    end

    Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
    Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
    Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed

    return {
        Small = create_pseudotag_for_ante(target_ante),
        Big = create_pseudotag_for_ante(target_ante),
    }
end

-- === Bosses (always-visible per-ante side panel) ===
--
-- Mirrors get_new_boss() (functions/common_events.lua, confirmed against the
-- installed Steamodded build's own copy - it adds an object-weights/pool-hook
-- branch Showman doesn't replicate, but falls through to the same vanilla
-- eligibility+pseudoseed('boss') logic when those optional features are off,
-- which they are here): eligibility is ante-gated (regular bosses need ante >=
-- boss.min and not a win_ante multiple; "showdown" bosses are the reverse, only
-- on win_ante multiples), then narrowed to whichever eligible bosses have been
-- used the fewest times this run (G.GAME.bosses_used), then picked with
-- pseudoseed('boss') - UNLIKE tags/packs, this key is genuinely never
-- ante-suffixed by Steamodded either (confirmed the same way, by reading its
-- lovely-patched common_events.lua directly), so it's a single persistent chain
-- for the whole run, only rerolled at the same ante-transition moment as tags
-- (reset_blinds(), when blind_states.Boss == 'Defeated'). So unlike
-- generateSkipTagsForAnte, a future ante's boss can't be looked up by a direct
-- formula call - it requires replaying every not-yet-rolled pick in order,
-- locally tracking bosses_used as we go so later picks in the same simulation
-- see the same "fewest used" narrowing vanilla would. The current ante's boss is
-- already decided and live-readable (G.GAME.round_resets.blind_choices.Boss),
-- same as tags. Verified live via ClaudeControl (predicted ante 2's boss from a
-- fresh ante-1 snapshot, then actually played to ante 2 and compared - matched).
local function get_eligible_bosses(ante, bosses_used)
    local win_ante = G.GAME.win_ante or 8
    local eligible = {}
    for k, v in pairs(G.P_BLINDS) do
        if v.boss then
            if not v.boss.showdown and (v.boss.min <= math.max(1, ante) and (math.max(1, ante) % win_ante ~= 0 or ante < 2)) then
                eligible[k] = true
            elseif v.boss.showdown and (ante % win_ante == 0) and ante >= 2 then
                eligible[k] = true
            end
        end
    end
    for k in pairs(G.GAME.banned_keys) do
        eligible[k] = nil
    end

    local min_use = 100
    for k in pairs(bosses_used) do
        if eligible[k] then
            eligible[k] = bosses_used[k]
            if eligible[k] <= min_use then min_use = eligible[k] end
        end
    end
    for k in pairs(eligible) do
        if eligible[k] and eligible[k] > min_use then eligible[k] = nil end
    end
    return eligible
end

function generateBossForAnte(target_ante)
    local real_ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    if target_ante == real_ante then
        return G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices.Boss or nil
    elseif target_ante < real_ante then
        return nil -- already rerolled past this point for real; not recoverable
    end

    Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
    Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
    Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed
    local bosses_used = shallowcopy(G.GAME.bosses_used)

    local boss = nil
    for ante = real_ante + 1, target_ante do
        local eligible = get_eligible_bosses(ante, bosses_used)
        local _, picked = Showman.FUNC.pseudorandom_element(eligible, Showman.FUNC.pseudoseed('boss'))
        boss = picked
        bosses_used[boss] = (bosses_used[boss] or 0) + 1
    end
    return boss
end

-- === Packs (2 shop booster-pack slots x 3 shop visits per ante) ===
--
-- Mirrors vanilla's get_pack('shop_pack') (functions/common_events.lua), called
-- twice per shop visit for its 2 pack slots (game.lua: `for i = 1, 2 do
-- get_pack('shop_pack') end`) - key = ('shop_pack')..ante, genuinely ante-suffixed
-- (get_pack has its own self-contained weighted pick over
-- G.P_CENTER_POOLS['Booster'], independent of get_current_pool, so this one
-- isn't affected by the vanilla/Steamodded ante-suffix difference above), so
-- unlike tags/bosses any future ante's packs CAN be looked up directly without
-- replaying earlier picks.
--
-- IMPORTANT: there are 3 shop visits per ante (after the Small, Big, and Boss
-- blinds), not 1 - each one calls get_pack('shop_pack'..ante) fresh for its own
-- 2 slots, and since pseudoseed auto-advances the SAME 'shop_pack'..ante key
-- every call, the 3 visits are 3 sequential pairs off one chain, not 3 copies
-- of the same pair. Confirmed live via ClaudeControl (shop 1 of an ante gave a
-- different pair than shop 2 of the very same ante, both compared against
-- real G.shop_booster contents) - this was originally missed (only the first
-- shop's pair was predicted) until the user pointed out there are 3 shops.
--
-- KNOWN LIMITATION: vanilla's very first pack of a run (G.GAME.first_shop_buffoon
-- not yet set) is a special case resolved with plain math.random(1,2) - genuine
-- engine randomness, not seed-derived - so it can't be predicted. That only ever
-- applies to slot 1 of shop visit 1 of the real current ante, before any shop
-- has been visited this run at all; every other slot resolves normally. Mirrors
-- the exact short-circuit vanilla's get_pack has (the special case returns
-- before ever touching the pseudoseed chain), so the picks after it land on the
-- same values vanilla's real draws would.
local function pick_pack_center(ante)
    local cume = 0
    for _, v in ipairs(G.P_CENTER_POOLS['Booster']) do
        if not G.GAME.banned_keys[v.key] then cume = cume + (v.weight or 1) end
    end
    local poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('shop_pack'..ante)) * cume
    local it, center = 0, nil
    for _, v in ipairs(G.P_CENTER_POOLS['Booster']) do
        if not G.GAME.banned_keys[v.key] then
            it = it + (v.weight or 1)
            if it >= poll and it - (v.weight or 1) <= poll then center = v; break end
        end
    end
    return center and center.key or nil
end

-- Returns {{shop1_slot1, shop1_slot2}, {shop2_slot1, shop2_slot2}, {shop3_slot1,
-- shop3_slot2}} - shop1_slot1 is nil exactly when vanilla's own unpredictable
-- first-pack-of-the-run special case applies (see above).
function generateShopPacksForAnte(ante)
    local real_ante = (G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
    Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
    Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
    Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed

    local first_pack_special = ante == real_ante and not G.GAME.first_shop_buffoon and not G.GAME.banned_keys['p_buffoon_normal_1']
    local shops = {}
    for shop_i = 1, 3 do
        local slot1
        -- Not `(shop_i==1 and first_pack_special) and nil or pick_pack_center(ante)`
        -- - that and/or idiom breaks when the "true" branch value is itself
        -- nil/false (`X and nil` is always nil, so the `or` unconditionally
        -- falls through) - a real bug caught live earlier this session.
        if not (shop_i == 1 and first_pack_special) then
            slot1 = pick_pack_center(ante)
        end
        local slot2 = pick_pack_center(ante)
        shops[shop_i] = { slot1, slot2 }
    end
    return shops
end

-- === Pack contents (hover preview) ===
--
-- Mirrors Card:open()'s per-kind card generation (card.lua, confirmed against
-- the installed Steamodded build's own lovely-patched copy) - same real
-- key_append strings ('ar1'/'pl1'/'spe'/'sta'/'buf') vanilla uses, routed through
-- create_card -> get_current_pool, which (per the note on generateSkipTagsForAnte
-- above) the installed Steamodded build ante-suffixes automatically. So - unlike
-- what a pure-vanilla reading would suggest - pack contents ARE directly
-- predictable by formula for any future ante, no chain-replay needed, same as
-- the pack-identity prediction above.
local function pseudocard_key_only(_type, key_append, ante)
    local _pool, _pool_key = Showman.FUNC.get_current_pool(_type, nil, nil, key_append, ante)
    return pseudorandom_pool_pick(_pool, _pool_key)
end

-- Standard packs' seal roll goes through Steamodded's own SMODS.poll_seal
-- (src/utils.lua) rather than vanilla's plain 4-branch roll - a weighted pick
-- over G.P_CENTER_POOLS['Seal'] (order matters: it's a weighted-range pick, so
-- this must walk the pool in the same array order SMODS does, not pairs()
-- order). mod=10 matches Card:open()'s own `SMODS.poll_seal({mod = 10})` call.
-- Presence-roll key 'stdseal'..ante, type-roll key 'stdsealtype'..ante (SMODS's
-- default key 'stdseal' with args.type_key uncomputed collapses to exactly
-- these two strings).
local function predict_pack_seal(ante)
    local pool = G.P_CENTER_POOLS['Seal'] or {}
    local available, base_weight = {}, 0
    for _, v in ipairs(pool) do
        local w = v.weight or 10
        if w > 0 then
            available[#available + 1] = { key = v.key, weight = (v.get_weight and v:get_weight()) or w }
            base_weight = base_weight + w
        end
    end
    if #available == 0 then return nil end
    local total_weight = base_weight + (base_weight / 2 * 98) -- base seal rate is 2%
    local type_weight = 0
    for _, v in ipairs(available) do type_weight = type_weight + v.weight end

    if Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('stdseal'..ante)) > 1 - (type_weight * 10 / total_weight) then
        local seal_poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('stdsealtype'..ante))
        local weight_i = 0
        for _, v in ipairs(available) do
            weight_i = weight_i + v.weight
            if seal_poll > 1 - (weight_i / type_weight) then return v.key end
        end
    end
    return nil
end

-- Returns an array of {key = center_key, edition = edition_or_nil, seal = seal_or_nil}.
function generatePackContents(pack_key, ante)
    local pack_center = G.P_CENTERS[pack_key]
    if not pack_center or pack_center.set ~= 'Booster' then return {} end
    local kind = pack_center.kind
    local count = pack_center.config.extra

    Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
    Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
    Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed

    local cards = {}
    for i = 1, count do
        if kind == 'Arcana' then
            cards[i] = { key = pseudocard_key_only('Tarot', 'ar1', ante) }
        elseif kind == 'Celestial' then
            cards[i] = { key = pseudocard_key_only('Planet', 'pl1', ante) }
        elseif kind == 'Spectral' then
            cards[i] = { key = pseudocard_key_only('Spectral', 'spe', ante) }
        elseif kind == 'Buffoon' then
            cards[i] = { key = pseudocard_key_only('Joker', 'buf', ante), edition = Showman.FUNC.poll_edition('edibuf'..ante) }
        elseif kind == 'Standard' then
            local is_enhanced = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('stdset'..ante)) > 0.6
            local ekey = is_enhanced and pseudocard_key_only('Enhanced', 'sta', ante) or 'c_base'
            local edition = Showman.FUNC.poll_edition('standard_edition'..ante, 2, true)
            cards[i] = { key = ekey, edition = edition, seal = predict_pack_seal(ante) }
        end
    end
    return cards
end

-- The Illusion voucher can swap a playing card's edition after the fact. Shared by
-- both branches of create_pseudocard_for_options below (previously duplicated, and
-- the non-Shop copy had a stale `v.type` check left over from a rename - `v` is the
-- outer queue-type string there, not the polled item, so that half of the check was
-- always false).
local function poll_illusion_edition(card_type)
    if not ((card_type == 'Base' or card_type == 'Enhanced')
    and G.GAME.used_vouchers["v_illusion"]
    and Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('illusion')) > 0.8) then
        return nil
    end
    local edition_poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('illusion'))
    if edition_poll > 1 - 0.15 then return "Polychrome"
    elseif edition_poll > 0.5 then return "Holo"
    else return "Foil"
    end
end

function create_pseudocard_for_options(ante, queue)
	local _center = G.P_CENTERS.c_empress
	local check_rate = 0
	local card = ""
	local edition = ""
    local sticker = {}
    local key = nil

    local q = ''
    local rare = nil
    local v = ''
    local pack = false
    local judgementRun = false
    if queue == 'Shop' then 
        q = 'sho'
        v = 'Joker'
    elseif queue == 'Rare Queue' then 
        q = 'sho'
        rare = 3
        v = 'Joker'
    elseif queue == 'Wraith/Rare Skip' then --currently same as shop rare
        q = 'sho'
        rare = 3
        v = 'Joker'
    elseif queue == 'Judgement' then
        q = 'jud'
        v = 'Joker'
        judgementRun = true
    elseif queue == 'Spectral (Shop)' then
        v = 'Spectral'
    elseif queue == 'Spectral (Pack)' then
        v = 'Spectral'
        pack = true    
    elseif queue == 'Tarot (Pack)' then
        v = 'Tarot'
        pack = true
    end

    if queue == 'Shop' then
        G.GAME.spectral_rate = G.GAME.spectral_rate or 0
        local total_rate = G.GAME.joker_rate + G.GAME.tarot_rate + G.GAME.planet_rate + G.GAME.playing_card_rate + G.GAME.spectral_rate
        local polled_rate = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('cdt'..ante))*total_rate
        local check_rate = 0
        for _, vi in ipairs({
        {type = 'Joker', val = G.GAME.joker_rate},
        {type = 'Tarot', val = G.GAME.tarot_rate},
        {type = 'Planet', val = G.GAME.planet_rate},
        {type = (G.GAME.used_vouchers["v_illusion"] and Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('illusion')) > 0.6) and 'Enhanced' or 'Base', val = G.GAME.playing_card_rate},
        {type = 'Spectral', val = G.GAME.spectral_rate},
        }) do
            if polled_rate > check_rate and polled_rate <= check_rate + vi.val then
                card, edition, sticker, key = Showman.FUNC.create_card(vi.type, nil, nil, nil, nil, nil, nil, 'sho', ante, false)
                edition = poll_illusion_edition(vi.type) or edition
                return card, edition, sticker, key
            end
        check_rate = check_rate + vi.val
        end
    else
        local runCount = 0
        if not judgementRun then
            card, edition, sticker, key = Showman.FUNC.create_card(v, nil, nil, rare, nil, nil, nil, q, ante, pack)
        else
            while judgementRun do
                --print("*** runcount" .. runCount)
                            --(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append, ante, pack)
                card, edition, sticker, key = Showman.FUNC.create_card(v, nil, nil, rare, nil, nil, nil, q, ante, pack)
                if not (sticker[1] == true or sticker[2] == true or sticker[3] == true) then
                    judgementRun = false
                end
                runCount = runCount + 1
            end
        end
        edition = poll_illusion_edition(v) or edition
        return card, edition, sticker, key
    end

end

Showman.FUNC = {}

-- Optional hook: function(pool_item) -> bool. Nil by default (plain engine, no
-- multiplayer awareness). Showman_order.lua sets this to exclude pool items using
-- the Multiplayer mod's ruleset when The Order is active. See get_current_pool.
Showman.FUNC.pool_exclude_hook = nil

-- Optional hook: function(ante) -> ante. Nil by default (plain engine, no
-- multiplayer awareness). Showman_order.lua sets this to force ante 0 while The
-- Order is active. See resolve_search_ante.
Showman.FUNC.ante_override_hook = nil

-- === RNG model detection ===
--
-- Whether get_current_pool's returned pool key gets ante-suffixed is NOT
-- consistent between environments: pure vanilla (BalatroSource) never
-- ante-suffixes it, but the Steamodded build most players actually run always
-- does (`return _pool, _pool_key..(not _legendary and G.GAME.round_resets.ante
-- or '')` in its lovely-patched functions/common_events.lua) - confirmed both
-- by reading that patched source directly and empirically, by predicting Skip
-- Tags with each formula and comparing against a real live run via the
-- ClaudeControl testing mod. An earlier pass through this file assumed pure
-- vanilla and shipped a wrong formula as a result.
--
-- Rather than hardcoding "if SMODS loaded then ante-suffix" (fragile - could
-- silently stop matching on a future Steamodded update, and doesn't obviously
-- generalize to whatever Multiplayer/other mods patch on top), this probes the
-- REAL currently-loaded global get_current_pool directly and observes what it
-- actually does with a harmless, side-effect-free call (the 'Tag' branch's
-- culling loop never touches pseudorandom state). That self-adapts to
-- whatever combination of vanilla/Steamodded/other-mod patches is really
-- running, including ones not written yet - "vanilla", "Steamodded", and
-- "Multiplayer-on-top-of-Steamodded" all reduce to the same one boolean this
-- actually depends on, so there's no need to separately special-case each one.
--
-- Showman.config.SEEK.rng_ante_suffix mirrors this as a 3-way user override
-- ("Auto"/"On"/"Off") for the rare case detection itself is ever wrong -
-- surfaced as a UI toggle in Showman_UI.lua.
Showman.RNG = Showman.RNG or {}

function Showman.RNG.detect_ante_suffix()
    local override = Showman.config.SEEK.rng_ante_suffix
    if override == "On" then return true end
    if override == "Off" then return false end

    if Showman.RNG.ante_suffix_cache ~= nil then return Showman.RNG.ante_suffix_cache end
    local ok, _, probe_key = pcall(get_current_pool, 'Tag', nil, nil, nil)
    if ok and probe_key then
        Showman.RNG.ante_suffix_cache = (probe_key ~= 'Tag')
    else
        -- Can't probe yet (too early, no G.GAME) - don't cache a guess, and
        -- default to the currently-known-correct behavior (matches the
        -- installed Steamodded build this mod actually ships against) rather
        -- than silently reverting to a formula already found to be wrong.
        return true
    end
    return Showman.RNG.ante_suffix_cache
end

function Showman.FUNC.pseudorandom_element(_t, seed)
  if seed then math.randomseed(seed) end
  local keys = {}
  for k, v in pairs(_t) do
      keys[#keys+1] = {k = k,v = v}
  end

  if keys[1] and keys[1].v and type(keys[1].v) == 'table' and keys[1].v.sort_id then
    table.sort(keys, function (a, b) return a.v.sort_id < b.v.sort_id end)
  else
    table.sort(keys, function (a, b) return a.k < b.k end)
  end

  local key = keys[math.random(#keys)].k
  return _t[key], key
end

function Showman.FUNC.random_string(length, seed)
  if seed then math.randomseed(seed) end
  local ret = ''
  for i = 1, length do
    ret = ret..string.char(math.random() > 0.7 and math.random(string.byte('1'),string.byte('9')) or (math.random() > 0.45 and math.random(string.byte('A'),string.byte('N')) or math.random(string.byte('P'),string.byte('Z'))))
  end
  return string.upper(ret)
end

function Showman.FUNC.pseudohash(str)
  if true then 
    local num = 1
    for i=#str, 1, -1 do
        num = ((1.1239285023/num)*string.byte(str, i)*math.pi + math.pi*i)%1
    end
    return num
  else
    str = string.sub(string.format("%-16s",str), 1, 24)
    
    local h = 0

    for i=#str, 1, -1 do
      h = bit.bxor(h, bit.lshift(h, 7) + bit.rshift(h, 3) + string.byte(str, i))
    end
    return tonumber(string.format("%.13f",math.sqrt(math.abs(h))%1))
  end
end

function Showman.FUNC.pseudoseed(key, predict_seed)
  if key == 'seed' then return math.random() end

  if predict_seed then 
    local _pseed = Showman.FUNC.pseudohash(key..(predict_seed or ''))
    _pseed = math.abs(tonumber(string.format("%.13f", (2.134453429141+_pseed*1.72431234)%1)))
    return (_pseed + (Showman.FUNC.pseudohash(predict_seed) or 0))/2
  end
  
  if not Showman.SEEK.GAME.pseudorandom[key] then 
    Showman.SEEK.GAME.pseudorandom[key] = Showman.FUNC.pseudohash(key..(Showman.SEEK.GAME.pseudorandom.seed or ''))
  end

  Showman.SEEK.GAME.pseudorandom[key] = math.abs(tonumber(string.format("%.13f", (2.134453429141+Showman.SEEK.GAME.pseudorandom[key]*1.72431234)%1)))
  return (Showman.SEEK.GAME.pseudorandom[key] + (Showman.SEEK.GAME.pseudorandom.hashed_seed or 0))/2
end

function Showman.FUNC.pseudorandom(seed, min, max)
  if type(seed) == 'string' then seed = Showman.FUNC.pseudoseed(seed) end
  math.randomseed(seed)
  if min and max then return math.random(min, max)
  else return math.random() end
end

-- Resolves the Soul/Black Hole/Base forced-key override. Shared by the plain engine
-- and any external generation strategy (e.g. Showman_order.lua) that needs the same
-- forcing rules but its own pool-pick tail.
function Showman.FUNC.resolve_forced_key(_type, ante, soulable, forced_key)
    if not forced_key and soulable and (not G.GAME.banned_keys['c_soul']) then
        if (_type == 'Tarot' or _type == 'Spectral' or _type == 'Tarot_Planet') and
        not (G.GAME.used_jokers['c_soul'] and not Showman.config.SEEK.apply_showman)  then
            if Showman.FUNC.pseudorandom('soul_'.._type..ante) > 0.997 then
                forced_key = 'c_soul'
            end
        end
        if (_type == 'Planet' or _type == 'Spectral') and
        not (G.GAME.used_jokers['c_black_hole'] and not Showman.config.SEEK.apply_showman)  then
            if Showman.FUNC.pseudorandom('soul_'.._type..ante) > 0.997 then
                forced_key = 'c_black_hole'
            end
        end
    end

    if _type == 'Base' then
        forced_key = 'c_base'
    end

    return forced_key
end

-- Resolves a (possibly forced) center from the current pool. `use_order_resample`
-- switches the resample seed formula used once a pool lands on 'UNAVAILABLE' -
-- this only differs for The Order (Showman_order.lua), which needs a single
-- normalised queue instead of a per-attempt resample suffix.
function Showman.FUNC.pick_from_pool(_type, _rarity, legendary, key_append, ante, forced_key, use_order_resample)
    if forced_key and not G.GAME.banned_keys[forced_key] then
        local center = G.P_CENTERS[forced_key]
        return center, (center.set ~= 'Default' and center.set or _type)
    end

    local _pool, _pool_key = Showman.FUNC.get_current_pool(_type, _rarity, legendary, key_append, ante)
    local center = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key))
    local it = 1
    while center == 'UNAVAILABLE' do
        it = it + 1
        center = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key..(use_order_resample and '' or ('_resample'..it))))
        if use_order_resample and it > 1000 then -- fallback
            center = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key..'_resample'..it))
        end
    end

    return G.P_CENTERS[center], _type
end

function Showman.FUNC.create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append, ante, pack)
    local area = area or G.jokers

    forced_key = Showman.FUNC.resolve_forced_key(_type, ante, soulable, forced_key)
    local center, resolved_type = Showman.FUNC.pick_from_pool(_type, _rarity, legendary, key_append, ante, forced_key, false)
    _type = resolved_type

	local edition = ""
    local sticker = {false, false, false}
    if _type == 'Joker' then
        if G.GAME.modifiers.all_eternal then
            sticker[1] = true
        end
        if (true) or (area == G.pack_cards) then
            local eternal_perishable_poll = Showman.FUNC.pseudorandom((area == G.pack_cards and 'packetper' or 'etperpoll')..ante)
            if G.GAME.modifiers.enable_eternals_in_shop and eternal_perishable_poll > 0.7 then
                sticker[1] = true
            elseif G.GAME.modifiers.enable_perishables_in_shop and ((eternal_perishable_poll > 0.4) and (eternal_perishable_poll <= 0.7)) then
                sticker[2] = true
            end
            if G.GAME.modifiers.enable_rentals_in_shop and Showman.FUNC.pseudorandom((area == G.pack_cards and 'packssjr' or 'ssjr')..ante) > 0.7 then
                sticker[3] = true
            end
        end

        edition = Showman.FUNC.poll_edition('edi'..(key_append or '')..ante)
    end

	return center.name, edition, sticker, center.key
end

function Showman.FUNC.poll_edition(_key, _mod, _no_neg, _guaranteed, _options)
    
    if true or (not _options and (_key == "wheel_of_fortune" or _key == "aura")) then -- set base game edition polling
		_options = { 'e_negative', 'e_polychrome', 'e_holo', 'e_foil' }
	end

	-- Use SMODS object weight system when enabled
	if SMODS.optional_features.object_weights then return SMODS.poll_object({type = 'Edition', seed = _key, guaranteed = _guaranteed, pool = _options, no_negative = _no_neg, mod = _mod}) end

	
	local _modifier = 1
	local edition_poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed(_key or 'edition_generic')) -- Generate the poll value
	local available_editions = {}                                          -- Table containing a list of editions and their weights

	if not _options then
		if _key == "wheel_of_fortune" or _key == "aura" then -- set base game edition polling
			_options = { 'e_negative', 'e_polychrome', 'e_holo', 'e_foil' }
		else
			local unordered_options = Showman.FUNC.get_current_pool("Edition", nil, nil, _key or 'edition_generic')
			_options = {}
			for _, edition in ipairs(unordered_options) do -- Flip the order of vanilla editions
				if G.P_CENTERS[edition] and G.P_CENTERS[edition].vanilla then
					table.insert(_options, 1, edition)
				else
					table.insert(_options, edition)
				end
			end
		end
	end
    for _, v in ipairs(_options) do
        local edition_option = {}
        if type(v) == 'string' then
            if v ~= 'UNAVAILABLE' then
                assert(string.sub(v, 1, 2) == 'e_', ("Edition \"%s\" is missing \"e_\" prefix."):format(v))
                edition_option = { name = v, weight = G.P_CENTERS[v].weight }
        		table.insert(available_editions, edition_option)
            end
        elseif type(v) == 'table' then
            assert(string.sub(v.name, 1, 2) == 'e_', ("Edition \"%s\" is missing \"e_\" prefix."):format(v.name))
            edition_option = { name = v.name, weight = v.weight }
        	table.insert(available_editions, edition_option)
        end
    end

	-- Calculate total weight of editions
	local total_weight = 0
	for _, v in ipairs(available_editions) do
        --print(v)
		total_weight = total_weight + (v.weight) -- total all the weights of the polled editions
	end
	-- sendDebugMessage("Edition weights: "..total_weight, "EditionAPI")
	-- If not guaranteed, calculate the base card rate to maintain base 4% chance of editions
	if not _guaranteed then
		_modifier = _mod or 1
		total_weight = total_weight + (total_weight / 4 * 96) -- Find total weight with base_card_rate as 96%
		for _, v in ipairs(available_editions) do
			v.weight = G.P_CENTERS[v.name]:get_weight()   -- Apply game modifiers where appropriate (defined in edition declaration)
		end
	end
	-- sendDebugMessage("Total weight: "..total_weight, "EditionAPI")
	-- sendDebugMessage("Editions: "..#available_editions, "EditionAPI")
	-- sendDebugMessage("Poll: "..edition_poll, "EditionAPI")

	-- Calculate whether edition is selected
	local weight_i = 0
	for _, v in ipairs(available_editions) do
		weight_i = weight_i + v.weight * _modifier
		-- sendDebugMessage(v.name.." weight is "..v.weight*_modifier, "EditionAPI")
		-- sendDebugMessage("Checking for "..v.name.." at "..(1 - (weight_i)/total_weight), "EditionAPI")
		if edition_poll > 1 - (weight_i) / total_weight then
			if not (v.name == 'e_negative' and _no_neg) then -- skip return if negative is selected and _no_neg is true
				-- sendDebugMessage("Matched edition: "..v.name, "EditionAPI")
                local finResult = ""
                if v.name == "e_negative" then return "Negative"
                elseif v.name == "e_polychrome" then return "Polychrome"
                elseif v.name == "e_holo" then return "Holo"
                else return "Foil"
                end
				--return v.name
			end
		end
	end

	return nil
    
    --[[_mod = _mod or 1
    local edition_poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed(_key or 'edition_generic'))
    if _guaranteed then
        if edition_poll > 1 - 0.003*25 and not _no_neg then
            return "Negative"
        elseif edition_poll > 1 - 0.006*25 then
            return "Polychrome"
        elseif edition_poll > 1 - 0.02*25 then
            return "Holo"
        elseif edition_poll > 1 - 0.04*25 then
            return "Foil"
        end
    else
        if edition_poll > 1 - 0.003*_mod and not _no_neg then
            return "Negative"
        elseif edition_poll > 1 - 0.006*G.GAME.edition_rate*_mod then
            return "Polychrome"
        elseif edition_poll > 1 - 0.02*G.GAME.edition_rate*_mod then
            return "Holo"
        elseif edition_poll > 1 - 0.04*G.GAME.edition_rate*_mod then
            return "Foil"
        end
    end
    return nil]]
end

function Showman.FUNC.get_current_pool(_type, _rarity, _legendary, _append, ante)
    -- Resolved BEFORE touching G.ARGS.TEMP_POOL below, not at the end of this
    -- function - Showman.RNG.detect_ante_suffix's first-ever (uncached) call
    -- probes the REAL global get_current_pool, which ALSO uses G.ARGS.TEMP_POOL
    -- as its own scratch table. Calling it after this function had already
    -- started building _pool into that same shared table let the nested probe
    -- silently wipe/corrupt it via EMPTY() before this function's own `return
    -- _pool, ...` ran - a real live crash ("attempt to index local 'center' (a
    -- nil value)" in Showman.UI.render_result_page, from a pool that came back
    -- empty on the Shop queue's first Analyze of a session). Resolving it here
    -- first means any nested corruption happens before this call starts using
    -- the table, not after.
    local ante_suffix = Showman.RNG.detect_ante_suffix()

    --print("*** " .. _type .. " " .. (_rarity or '') .. " " .. (_append or ''))
    --create the pool
    G.ARGS.TEMP_POOL = EMPTY(G.ARGS.TEMP_POOL)
    local _pool, _starting_pool, _pool_key, _pool_size = G.ARGS.TEMP_POOL, nil, '', 0

    if _type == 'Joker' then 
        local rarity = _rarity or Showman.FUNC.pseudorandom('rarity'..ante..(_append or '')) 
        rarity = (_legendary and 4) or (rarity > 0.95 and 3) or (rarity > 0.7 and 2) or 1
        _starting_pool, _pool_key =  G.P_JOKER_RARITY_POOLS[rarity], 'Joker'..rarity..((not _legendary and _append) or '')
    else _starting_pool, _pool_key = G.P_CENTER_POOLS[_type], _type..(_append or '')
    end

    --cull the pool
    for k, v in ipairs(_starting_pool) do
        local add = nil
        if _type == 'Enhanced' then
            add = true
        elseif _type == 'Demo' then
            if v.pos and v.config then add = true end
        elseif _type == 'Tag' then
            if (not v.requires or (G.P_CENTERS[v.requires] and G.P_CENTERS[v.requires].discovered)) and 
            (not v.min_ante or v.min_ante <= ante) then
                add = true
            end
        elseif not (G.GAME.used_jokers[v.key] and not Showman.config.SEEK.apply_showman) and
            (v.unlocked ~= false or v.rarity == 4) then
            if v.set == 'Voucher' then
                if not G.GAME.used_vouchers[v.key] then 
                    local include = true
                    if v.requires then 
                        for kk, vv in pairs(v.requires) do
                            if not G.GAME.used_vouchers[vv] then 
                                include = false
                            end
                        end
                    end
                    if G.shop_vouchers and G.shop_vouchers.cards then
                        for kk, vv in ipairs(G.shop_vouchers.cards) do
                            if vv.config.center.key == v.key then include = false end
                        end
                    end
                    if include then
                        add = true
                    end
                end
            elseif v.set == 'Planet' then
                if (not v.config.softlock or G.GAME.hands[v.config.hand_type].played > 0) then
                    add = true
                end
            elseif v.enhancement_gate then
                add = nil
                for kk, vv in pairs(G.playing_cards) do
                    if vv.config.center.key == v.enhancement_gate then
                        add = true
                    end
                end
            else
                add = true
            end
            if v.name == 'Black Hole' or v.name == 'The Soul' then
                add = false
            end
        end

        if v.no_pool_flag and G.GAME.pool_flags[v.no_pool_flag] then add = nil end
        if v.yes_pool_flag and not G.GAME.pool_flags[v.yes_pool_flag] then add = nil end
        
        if add and not G.GAME.banned_keys[v.key] then
            _pool[#_pool + 1] = v.key
            _pool_size = _pool_size + 1
        else
            _pool[#_pool + 1] = 'UNAVAILABLE'
        end
        -- Optional external exclusion hook (set by Showman_order.lua when The Order
        -- is active). Left nil here so the plain engine has no multiplayer awareness.
        if Showman.FUNC.pool_exclude_hook and Showman.FUNC.pool_exclude_hook(v) then
            table.remove(_pool) -- remove whatever was just done
            if add and not G.GAME.banned_keys[v.key] then
                _pool_size = _pool_size - 1
            end
        end
    end

    --if pool is empty
    if _pool_size == 0 then
        _pool = EMPTY(G.ARGS.TEMP_POOL)
        if _type == 'Tarot' or _type == 'Tarot_Planet' then _pool[#_pool + 1] = "c_strength"
        elseif _type == 'Planet' then _pool[#_pool + 1] = "c_pluto"
        elseif _type == 'Spectral' then _pool[#_pool + 1] = "c_incantation"
        elseif _type == 'Joker' then _pool[#_pool + 1] = "j_joker"
        elseif _type == 'Demo' then _pool[#_pool + 1] = "j_joker"
        elseif _type == 'Voucher' then _pool[#_pool + 1] = "v_blank"
        elseif _type == 'Tag' then _pool[#_pool + 1] = "tag_handy"
        else _pool[#_pool + 1] = "j_joker"
        end
    end

    -- Ante-suffixing is conditional on the live-detected RNG model (ante_suffix,
    -- resolved at the top of this function - see its comment there) rather than
    -- unconditional - this single change is what makes every caller (Tags,
    -- Shop, Rare Queue, Judgement, Spectral, Tarot, pack contents, ...)
    -- automatically track whichever environment is actually running instead of
    -- assuming one.
    if not _legendary and ante_suffix then
        return _pool, _pool_key..ante
    end
    return _pool, _pool_key
end


function Showman.FUNC.reset_idol_card()
    G.GAME.current_round.idol_card.rank = 'Ace'
    G.GAME.current_round.idol_card.suit = 'Spades'
    local valid_idol_cards = {}
    for k, v in ipairs(G.playing_cards) do
        if v.ability.effect ~= 'Stone Card' then
            valid_idol_cards[#valid_idol_cards+1] = v
        end
    end
    if valid_idol_cards[1] then 
        local idol_card = Showman.FUNC.pseudorandom_element(valid_idol_cards, Showman.FUNC.pseudoseed('idol'..G.GAME.round_resets.ante))
        G.GAME.current_round.idol_card.rank = idol_card.base.value
        G.GAME.current_round.idol_card.suit = idol_card.base.suit
        G.GAME.current_round.idol_card.id = idol_card.base.id
    end
end

function Showman.FUNC.reset_mail_rank()
    G.GAME.current_round.mail_card.rank = 'Ace'
    local valid_mail_cards = {}
    for k, v in ipairs(G.playing_cards) do
        if v.ability.effect ~= 'Stone Card' then
            valid_mail_cards[#valid_mail_cards+1] = v
        end
    end
    if valid_mail_cards[1] then 
        local mail_card = Showman.FUNC.pseudorandom_element(valid_mail_cards, Showman.FUNC.pseudoseed('mail'..G.GAME.round_resets.ante))
        G.GAME.current_round.mail_card.rank = mail_card.base.value
        G.GAME.current_round.mail_card.id = mail_card.base.id
    end
end

function Showman.FUNC.reset_ancient_card()
    local ancient_suits = {}
    for k, v in ipairs({'Spades','Hearts','Clubs','Diamonds'}) do
        if v ~= G.GAME.current_round.ancient_card.suit then ancient_suits[#ancient_suits + 1] = v end
    end
    local ancient_card = Showman.FUNC.pseudorandom_element(ancient_suits, Showman.FUNC.pseudoseed('anc'..G.GAME.round_resets.ante))
    G.GAME.current_round.ancient_card.suit = ancient_card
end

function Showman.FUNC.reset_castle_card()
    G.GAME.current_round.castle_card.suit = 'Spades'
    local valid_castle_cards = {}
    for k, v in ipairs(G.playing_cards) do
        if v.ability.effect ~= 'Stone Card' then
            valid_castle_cards[#valid_castle_cards+1] = v
        end
    end
    if valid_castle_cards[1] then 
        local castle_card = Showman.FUNC.pseudorandom_element(valid_castle_cards, Showman.FUNC.pseudoseed('cas'..G.GAME.round_resets.ante))
        G.GAME.current_round.castle_card.suit = castle_card.base.suit
    end
end

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function findShowmanDirectory(directory)
  for _, item in ipairs(nfs.getDirectoryItems(directory)) do
    local itemPath = directory .. "/" .. item
    if
      nfs.getInfo(itemPath, "directory")
      and string_lower(item):find("showman")
    then
      return itemPath
    end
  end
  return nil
end