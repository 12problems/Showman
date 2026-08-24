local lovely = require("lovely")
local nativefs = require("nativefs")

Showman.SEEK.scale = 0.7
Showman.SEEK.row_count = 4
Showman.SEEK.card_count = 6

local analyzeMax = {100, 1000, 10000}

-- "Shop Preview" is a Queue option like Shop/Rare Queue/etc, but instead of
-- populating the results CardArea grid it replaces the whole right-hand
-- display area with a combined Skip Tags + Packs + Boss view for the selected
-- ante - see Showman.UI.build_shop_preview_definition/refresh_right_panel.
Showman.SHOP_PREVIEW_QUEUE = "Shop Preview"

local function is_shop_preview()
	return Showman.config.SEEK.search_queue == Showman.SHOP_PREVIEW_QUEUE
end

G.FUNCS.change_search_queue = function(x)
	local was_shop_preview = is_shop_preview()
	Showman.config.SEEK.search_queue = x.to_val
	Showman.config.SEEK.search_queueID = x.to_key
	Showman.writeConfig()
	-- Only rebuild the right panel at the Shop-Preview boundary - switching
	-- among the other (normal) queues has never rebuilt/cleared the results
	-- grid on its own (only Analyze does), and that shouldn't change here.
	if is_shop_preview() ~= was_shop_preview then
		Showman.UI.refresh_right_panel()
	end
end

-- Single ante selector: normal queues (Shop/Rare/etc) use it to pick which ante
-- to generate against; while the Shop Preview queue is selected it also drives
-- the combined Tags/Packs/Boss display in the right panel (see
-- Showman.UI.refresh_right_panel). Options are display strings ("Ante N"), so
-- the actual numeric ante comes from x.to_key (the cycle index) via
-- Showman.ante_options, not x.to_val.
G.FUNCS.change_search_ante = function(x)
	Showman.config.SEEK.search_ante = Showman.ante_options[x.to_key] or x.to_key
	Showman.writeConfig()
	if is_shop_preview() then
		Showman.UI.refresh_right_panel()
	end
end

G.FUNCS.set_to_current_ante = function(x)
	if G.STAGE == G.STAGES.RUN then
		Showman.config.SEEK.search_ante = G.GAME.round_resets.ante
		Showman.writeConfig()
		local ante_page_cycle = G.OVERLAY_MENU:get_UIE_by_ID("showman_ante_preview_page")
		if ante_page_cycle then
			local ref = ante_page_cycle.children[1].config.ref_table
			ref.current_option = Showman.config.SEEK.search_ante
			ref.current_option_val = ref.options[ref.current_option]
			ante_page_cycle.children[1].UIBox:recalculate()
		end
		if is_shop_preview() then
			Showman.UI.refresh_right_panel()
		end
	end
end

G.FUNCS.change_search_depth = function(x)
	Showman.config.SEEK.search_depth = x.to_val
	Showman.config.SEEK.search_depthID = x.to_key
	Showman.writeConfig()

	Showman.joker_options = {}
	for i = 1, math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*Showman.SEEK.row_count)) do
		table.insert(Showman.joker_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*Showman.SEEK.row_count))))
	end
	local jk_page_cycle = G.OVERLAY_MENU:get_UIE_by_ID("showman_joker_page")
	if jk_page_cycle then
		local ref = jk_page_cycle.children[1].config.ref_table
		ref.options = Showman.joker_options
		jk_page_cycle.children[1].UIBox:recalculate()
	end
end

-- RNG model override: "Auto" (default) lets Showman.RNG.detect_ante_suffix
-- (Showman_seek.lua) probe the live get_current_pool itself; "On"/"Off" force
-- the ante-suffix behavior manually for the rare case detection is wrong.
Showman.rng_model_options = {"Auto", "On", "Off"}

G.FUNCS.change_rng_model = function(x)
	Showman.config.SEEK.rng_ante_suffix = x.to_val == "Auto" and nil or x.to_val
	Showman.writeConfig()
	Showman.RNG.ante_suffix_cache = nil
end

-- 1-based index into Showman.rng_model_options matching the saved override
-- (nil/absent = "Auto"), for the cycle's initial current_option.
local function rng_model_option_index()
	local override = Showman.config.SEEK.rng_ante_suffix
	if override == "On" then return 2 end
	if override == "Off" then return 3 end
	return 1
end

Showman.ui = {}

-- Showman.UI (capitalized - distinct from the Showman.ui state table above) holds
-- the rendering helpers shared by analyze, the initial create_tabs render, and the
-- page-cycle callback. All three used to carry their own copy of "resolve a center
-- from Showman.ui_jokers by key, build a Card, apply edition/stickers, emplace."
Showman.UI = {}

function Showman.UI.clear_result_cards()
	for j = 1, #Showman.ui_card_area do
		for i = #Showman.ui_card_area[j].cards, 1, -1 do
			if Showman.ui_card_area[j].cards[i] == nil then goto continuee end
			local c = Showman.ui_card_area[j]:remove_card(Showman.ui_card_area[j].cards[i])
			c:remove()
			c = nil
			::continuee::
		end
	end
end

-- Renders the current page (Showman.ui_search_page) of Showman.ui_jokers /
-- ui_editions / ui_stickers into Showman.ui_card_area. Showman.ui_jokers holds
-- center keys (e.g. "j_blueprint"), not display names - resolved with a direct
-- G.P_CENTERS lookup instead of a linear scan for the matching .name.
function Showman.UI.render_result_page()
	for i = 1, Showman.SEEK.card_count do
		for j = 1, #Showman.ui_card_area do
			local index = (i+(j-1)*Showman.SEEK.card_count + (Showman.SEEK.card_count*#Showman.ui_card_area*(Showman.ui_search_page - 1)))-1
			local center = G.P_CENTERS[Showman.ui_jokers[index]]
			if not center then
				break
			end
			local card = Card(Showman.ui_card_area[j].T.x + Showman.ui_card_area[j].T.w/2, Showman.ui_card_area[j].T.y, G.CARD_W*Showman.SEEK.scale, G.CARD_H*Showman.SEEK.scale, nil, center)
			local edition = Showman.ui_editions[index]
			local sticker = Showman.ui_stickers[index]
			if edition == "Foil" then edition = {foil = true}
			elseif edition == "Holo" then edition = {holo = true}
			elseif edition == "Polychrome" then edition = {polychrome = true}
			elseif edition == "Negative" then edition = {negative = true}
			else edition = nil end
			card:set_edition(edition, true, true)
			if sticker[1] then card:set_eternal(true) end
			if sticker[2] then card:set_perishable(true) end
			if sticker[3] then card:set_rental(true) end
			card.sticker = get_joker_win_sticker(center)
			Showman.ui_card_area[j]:emplace(card)
		end
	end
end

G.FUNCS.analyze = function(x)
	-- No-op while Shop Preview is selected: that queue doesn't use the
	-- results CardArea grid at all, and switching queues in/out of Shop
	-- Preview tears down and rebuilds Showman.ui_card_area (see
	-- Showman.UI.build_result_card_areas's comment) - clear_result_cards
	-- would be operating on stale/removed objects. Real crash caught live
	-- ("attempt to get length of field 'cards' (a nil value)").
	if is_shop_preview() then return end
	Showman.UI.clear_result_cards()
	if G.STAGE == G.STAGES.RUN then
		G.SETTINGS.paused = true
		Showman.joker_options = {}
		for i = 1, math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*Showman.SEEK.row_count)) do
			table.insert(Showman.joker_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*Showman.SEEK.row_count))))
		end
		local out, cards, editions, stickers = generateWithOptions(Showman.config.SEEK.search_depth, Showman.config.SEEK.search_queue)
		Showman.ui_jokers = cards
		Showman.ui_editions = editions
		Showman.ui_stickers = stickers
		Showman.ui_search_page = 1

		local jk_page_cycle = G.OVERLAY_MENU:get_UIE_by_ID("showman_joker_page")
		if jk_page_cycle then
			local ref = jk_page_cycle.children[1].config.ref_table
			ref.current_option = 1
			ref.current_option_val = ref.options[ref.current_option]
			jk_page_cycle.children[1].UIBox:recalculate()
		end

		Showman.UI.render_result_page()
	end
end

Showman.G_FUNCS_options_ref = G.FUNCS.options
G.FUNCS.options = function(e)
	Showman.G_FUNCS_options_ref(e)
end

Showman.antes = {"Shop", "Rare Queue", "Wraith/Rare Skip", "Judgement", "Spectral (Shop)", "Spectral (Pack)", "Tarot (Pack)", Showman.SHOP_PREVIEW_QUEUE}
Showman.ante_options = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39}

-- "Ante N" display-string options for the single ante selector (create_option_cycle
-- needs option labels, not raw numbers). Index i still corresponds to ante i,
-- matching Showman.ante_options, so x.to_key from the cycle callback is the actual
-- ante number.
Showman.ante_preview_options = {}
for i = 1, #Showman.ante_options do
	table.insert(Showman.ante_preview_options, "Ante "..Showman.ante_options[i])
end

Showman.ui_card_area = {}
Showman.joker_options = {}
Showman.deck_tables = {}
Showman.ui_search_page = 1

-- Size (in tiles) for icon-only sprites (tags/boss) in the Shop Preview panel -
-- bigger than the old cramped left-panel widgets now that they live in the
-- large display area.
Showman.TAG_ICON_SIZE = 1.1
Showman.BOSS_ICON_SIZE = 1.7
Showman.PACK_SCALE = 0.75

-- Builds a pack card's hover-popup content: predicted card names (with
-- edition/seal noted) for `pack_key` at `ante`, via generatePackContents
-- (Showman_seek.lua). Plain G.UIT.T rows only - no embedded Card/Sprite objects
-- and no reuse of generate_card_ui/card_h_popup (a previous attempt at a Skip
-- Tags hover popup crashed doing that on a bare Sprite - not something a real
-- Card needs, but the safe pattern is worth keeping regardless).
--
-- IMPORTANT: .config.h_popup must be the already-built UI tree TABLE, not a
-- function - confirmed the hard way (a live crash, "engine/ui.lua:257: attempt
-- to index local 'node' (a function value)"): UIBox:init does `self.definition
-- = args.definition` with no call, so Node:hover()'s `UIBox{definition =
-- self.config.h_popup, ...}` needs h_popup already evaluated. Vanilla's own
-- Card:hover() confirms this too - it does `self.config.h_popup =
-- G.UIDEF.card_h_popup(self)`, calling it immediately, not storing the
-- function. build_pack_contents_popup here returns the table directly for the
-- same reason; called fresh on each hover (below) rather than cached.
local function build_pack_contents_popup(pack_key, ante)
	local center = G.P_CENTERS[pack_key]
	local rows = {
		{n=G.UIT.R, config={align="cm", padding=0.05}, nodes={
			{n=G.UIT.T, config={text = (center and center.name) or pack_key, colour = G.C.WHITE, scale = 0.4}}
		}}
	}
	local contents = generatePackContents(pack_key, ante)
	for _, c in ipairs(contents) do
		local cc = G.P_CENTERS[c.key]
		local name = (cc and cc.name) or c.key
		if c.edition then name = name.." ("..c.edition..")" end
		if c.seal then name = name.." ["..c.seal.." Seal]" end
		rows[#rows+1] = {n=G.UIT.R, config={align="cm"}, nodes={
			{n=G.UIT.T, config={text = name, colour = G.C.WHITE, scale = 0.32}}
		}}
	end
	if #contents == 0 then
		rows[#rows+1] = {n=G.UIT.R, config={align="cm"}, nodes={
			{n=G.UIT.T, config={text = "?", colour = G.C.WHITE, scale = 0.32}}
		}}
	end
	return {n=G.UIT.ROOT, config={align="cm", padding=0.1, r=0.1, colour=G.C.BLACK, minw=4}, nodes=rows}
end

-- Builds one pack slot: a fresh 1-card CardArea holding a real Card for
-- `pack_key` (or an empty CardArea if pack_key is nil - the unpredictable
-- first-pack-of-the-run special case), wrapped in a G.UIT.O node. Real Cards
-- already have a working hover popup, but Card:hover() (card.lua)
-- unconditionally rebuilds and overwrites .config.h_popup from it on every
-- hover, so setting it once after creating the card doesn't stick - fixed by
-- overriding this card INSTANCE's .hover method (only affects this one
-- prediction tile, not real shop/pack cards anywhere else in the game).
local function build_pack_slot_node(pack_key, ante)
	local card_area = CardArea(G.ROOM.T.x, G.ROOM.T.h, G.CARD_W*Showman.PACK_SCALE, G.CARD_H*Showman.PACK_SCALE, {card_limit = 1, type = 'title', highlight_limit = 0})
	local center = pack_key and G.P_CENTERS[pack_key]
	if center then
		local card = Card(card_area.T.x + card_area.T.w/2, card_area.T.y, G.CARD_W*Showman.PACK_SCALE, G.CARD_H*Showman.PACK_SCALE, nil, center, {bypass_discovery_center = true, bypass_discovery_ui = true})
		-- Computed once here (build time), not inside the hover closure - a
		-- live first-hover-only glitch (a stale/incomplete popup on the very
		-- first hover of a freshly-built card, self-correcting on the next
		-- hover) went away once this moved out of hover-time execution, so
		-- keeping it this way even though the exact cause wasn't fully
		-- root-caused.
		local popup = build_pack_contents_popup(pack_key, ante)
		card.hover = function(self)
			self:juice_up(0.05, 0.03)
			play_sound('paper1', math.random()*0.2 + 0.9, 0.35)
			if self.facing == 'front' and (not self.states.drag.is or G.CONTROLLER.HID.touch) and not self.no_ui and not G.debug_tooltip_toggle then
				self.config.h_popup = popup
				self.config.h_popup_config = {align = 'cb', offset = {x = 0, y = -0.1}, parent = self}
				Node.hover(self)
			end
		end
		card_area:emplace(card)
	end
	return {n=G.UIT.O, config={object = card_area}}
end

-- One "Shop N" column: a label plus its 2 pack slots stacked vertically.
local function build_shop_column(shop_pair, shop_index, ante)
	return {n=G.UIT.C, config={align="cm", padding=0.12}, nodes={
		{n=G.UIT.R, config={align="cm", padding=0.03}, nodes={
			{n=G.UIT.T, config={text = "Shop "..shop_index, colour = G.C.WHITE, scale = 0.35}}
		}},
		{n=G.UIT.R, config={align="cm", padding=0.04}, nodes={build_pack_slot_node(shop_pair[1], ante)}},
		{n=G.UIT.R, config={align="cm", padding=0.04}, nodes={build_pack_slot_node(shop_pair[2], ante)}},
	}}
end

-- Boss icon + Skip Tags icon pair, both with hover popups - same plain
-- hand-built-tree pattern as build_pack_contents_popup above (never a function,
-- always the already-built table). Bare Sprite/AnimatedSprite objects don't
-- have hover/collide enabled by default (unlike Card, which turns these on in
-- its own constructor), so both need .states.hover.can/.states.collide.can set
-- explicitly for Node:hover() to ever fire on them at all.
local function build_shop_preview_header(ante)
	local boss_key = generateBossForAnte(ante)
	local boss_def = boss_key and G.P_BLINDS[boss_key]
	local boss_sprite = SMODS.create_sprite(0, 0, Showman.BOSS_ICON_SIZE, Showman.BOSS_ICON_SIZE, 'blind_chips', (boss_def and boss_def.pos) or (G.b_undiscovered and G.b_undiscovered.pos) or {x = 0, y = 0})
	boss_sprite.states.hover.can = true
	boss_sprite.states.collide.can = true
	if boss_def then
		boss_sprite.config.h_popup = {n=G.UIT.ROOT, config={align="cm", padding=0.1, r=0.1, colour=G.C.BLACK, minw=3}, nodes={
			{n=G.UIT.R, config={align="cm"}, nodes={{n=G.UIT.T, config={text = boss_def.name or boss_key, colour = G.C.WHITE, scale = 0.4}}}}
		}}
		boss_sprite.config.h_popup_config = {align = 'cb', offset = {x = 0, y = -0.1}, parent = boss_sprite}
	end

	local tags = generateSkipTagsForAnte(ante)
	local function tag_sprite(key)
		local tag_def = key and G.P_TAGS[key]
		local sprite = Sprite(0, 0, Showman.TAG_ICON_SIZE, Showman.TAG_ICON_SIZE, G.ASSET_ATLAS["tags"], (tag_def and tag_def.pos) or G.tag_undiscovered.pos)
		sprite.states.hover.can = true
		sprite.states.collide.can = true
		if tag_def then
			sprite.config.h_popup = {n=G.UIT.ROOT, config={align="cm", padding=0.1, r=0.1, colour=G.C.BLACK, minw=3}, nodes={
				{n=G.UIT.R, config={align="cm"}, nodes={{n=G.UIT.T, config={text = tag_def.name or key, colour = G.C.WHITE, scale = 0.4}}}}
			}}
			sprite.config.h_popup_config = {align = 'cb', offset = {x = 0, y = -0.1}, parent = sprite}
		end
		return sprite
	end
	local small_sprite = tag_sprite(tags and tags.Small)
	local big_sprite = tag_sprite(tags and tags.Big)

	return {n=G.UIT.R, config={align="cm", padding=0.15}, nodes={
		{n=G.UIT.C, config={align="cm", padding=0.2}, nodes={
			{n=G.UIT.R, config={align="cm"}, nodes={{n=G.UIT.T, config={text = "Boss", colour = G.C.WHITE, scale = 0.4}}}},
			{n=G.UIT.R, config={align="cm"}, nodes={{n=G.UIT.O, config={w = Showman.BOSS_ICON_SIZE, h = Showman.BOSS_ICON_SIZE, colour = G.C.WHITE, object = boss_sprite}}}},
		}},
		{n=G.UIT.C, config={align="cm", padding=0.2}, nodes={
			{n=G.UIT.R, config={align="cm"}, nodes={{n=G.UIT.T, config={text = "Skip Tags", colour = G.C.WHITE, scale = 0.4}}}},
			{n=G.UIT.R, config={align="cm"}, nodes={
				{n=G.UIT.C, config={align="cm", padding=0.05}, nodes={{n=G.UIT.O, config={w = Showman.TAG_ICON_SIZE, h = Showman.TAG_ICON_SIZE, colour = G.C.WHITE, object = small_sprite}}}},
				{n=G.UIT.C, config={align="cm", padding=0.05}, nodes={{n=G.UIT.O, config={w = Showman.TAG_ICON_SIZE, h = Showman.TAG_ICON_SIZE, colour = G.C.WHITE, object = big_sprite}}}},
			}},
		}},
	}}
end

-- The Shop Preview tree: Boss+Tags header, then 3 shop columns of 2 packs
-- each (there are 3 shop visits per ante - after Small, Big, and Boss - not
-- 1, each with its own 2 pack slots - see generateShopPacksForAnte's comment
-- in Showman_seek.lua), then the ante pager (no joker-page pager here, it has
-- nothing to page through in this mode).
function Showman.UI.build_shop_preview_definition()
	local ante = Showman.config.SEEK.search_ante or 1
	local shops = generateShopPacksForAnte(ante)
	local shop_columns = {}
	for i = 1, 3 do
		shop_columns[i] = build_shop_column(shops[i], i, ante)
	end
	return {
		n = G.UIT.ROOT,
		config = {align = "cm", padding = 0.1, colour = G.C.CLEAR},
		nodes = {
			build_shop_preview_header(ante),
			{n=G.UIT.R, config={align="cm", padding=0.1}, nodes=shop_columns},
			{n=G.UIT.R, config={align="cm", padding=0.25}, nodes={
				{n=G.UIT.C, config={align="cm"}, nodes={
					create_option_cycle({
						id = 'showman_ante_preview_page',
						options = Showman.ante_preview_options,
						w = 3,
						h = 0.3,
						cycle_shoulders = true,
						opt_callback = 'change_search_ante',
						current_option = ante,
						colour = G.C.PURPLE,
						no_pips = true,
						focus_args = {snap_to = true, nav = 'wide'}
					})
				}}
			}}
		}
	}
end

-- Rebuilds Showman.ui_card_area/Showman.deck_tables fresh. MUST happen every
-- time build_results_definition runs, not just once at tab-open - removing a
-- UIBox (Showman.UI.refresh_right_panel, when switching queues in/out of Shop
-- Preview) cascades and calls :remove() on every embedded child object too
-- (engine/node.lua Node:remove() recurses self.children), which destroys the
-- old CardAreas. A previous version of this file only built these once and
-- kept referencing the same globals afterward, which crashed live
-- ("engine/ui.lua:411: attempt to index field 'object' (a nil value)") the
-- first time a user switched Shop Preview -> a normal queue, because it tried
-- to reuse CardArea objects that switching INTO Shop Preview had already torn
-- down.
function Showman.UI.build_result_card_areas()
	Showman.ui_card_area = {}
	Showman.deck_tables = {}
	for j = 1, Showman.SEEK.row_count do
		Showman.ui_card_area[j] = CardArea(
		G.ROOM.T.x + 0.2*G.ROOM.T.w/2,
		G.ROOM.T.h,
		Showman.SEEK.card_count*Showman.SEEK.scale*G.CARD_W,
		Showman.SEEK.scale*G.CARD_H,
		{card_limit = Showman.SEEK.card_count, type = 'title', highlight_limit = 0, collection = true})

		table.insert(Showman.deck_tables,
			{n=G.UIT.R, config={align = "cm", padding = 0.02, no_fill = true}, nodes={
				{n=G.UIT.O, config={object = Showman.ui_card_area[j]}}
		}})
	end
end

-- The normal results tree (joker/card search results) - what the right panel
-- showed before Shop Preview existed. Rebuilding here means switching back to
-- a normal queue after visiting Shop Preview starts the results grid empty
-- again (an expected side effect of the CardArea teardown above, not a bug -
-- click Analyze again), same as vanilla's own tab system: switching tabs and
-- back always rebuilds that tab's contents fresh rather than resuming state.
function Showman.UI.build_results_definition()
	Showman.UI.build_result_card_areas()
	return {
		n = G.UIT.ROOT,
		config = {align = "cm", padding = 0.02, colour = G.C.CLEAR},
		nodes = {
			{n=G.UIT.R, config={align="cm", padding=0.02, r=0.1, colour=darken(G.C.UI.TRANSPARENT_DARK, 0.25)}, nodes=Showman.deck_tables},
			{n=G.UIT.R, config={align="cm", padding=0.2}, nodes={
				{n=G.UIT.C, config={align="cm", padding=0.15}, nodes={
					create_option_cycle({
						id = 'showman_joker_page',
						options = Showman.joker_options,
						w = 3,
						h = 0.3,
						cycle_shoulders = true,
						opt_callback = 'showman_ui_joker_page',
						current_option = Showman.ui_search_page or 1,
						colour = G.C.PURPLE,
						no_pips = true,
						focus_args = {snap_to = true, nav = 'wide'}
					})
				}},
				{n=G.UIT.C, config={align="cm", padding=0.15}, nodes={
					create_option_cycle({
						id = 'showman_ante_preview_page',
						options = Showman.ante_preview_options,
						w = 3,
						h = 0.3,
						cycle_shoulders = true,
						opt_callback = 'change_search_ante',
						current_option = Showman.config.SEEK.search_ante or 1,
						colour = G.C.PURPLE,
						no_pips = true,
						focus_args = {snap_to = true, nav = 'wide'}
					})
				}}
			}}
		}
	}
end

function Showman.UI.build_right_panel_definition()
	if is_shop_preview() then
		return Showman.UI.build_shop_preview_definition()
	end
	return Showman.UI.build_results_definition()
end

-- Swaps the right panel's whole content, mirroring vanilla's own
-- G.FUNCS.change_tab (functions/button_callbacks.lua) exactly: find the slot
-- node by id, remove its current UIBox, build a fresh one, recalculate. Used
-- whenever the right panel's node STRUCTURE needs to change (not just data
-- within existing nodes, which the create_option_cycle cycles elsewhere in
-- this file handle via a plain :recalculate() on their own ref_table).
function Showman.UI.refresh_right_panel()
	local slot = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID('showman_right_slot')
	if not slot then return end
	if slot.config.object then slot.config.object:remove() end
	slot.config.object = UIBox{
		definition = Showman.UI.build_right_panel_definition(),
		config = {offset = {x = 0, y = 0}, parent = slot, type = 'cm'}
	}
	slot.UIBox:recalculate()
end

local ct = create_tabs
function create_tabs(args)
	if args and args.tab_h == 7.05 then
		args.tabs[#args.tabs + 1] = {
			label = "Showman",
			tab_definition_function = function()

				Showman.joker_options = {}
				for i = 1, math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*Showman.SEEK.row_count)) do
					table.insert(Showman.joker_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*Showman.SEEK.row_count))))
				end

				-- Built here (before render_result_page/the tree below), not
				-- inline in the old duplicate copy of this loop that used to
				-- live in this function directly - build_right_panel_definition
				-- (via build_results_definition, when not in Shop Preview)
				-- rebuilds Showman.ui_card_area itself now, and needs to run
				-- before render_result_page populates it.
				local right_panel_definition = Showman.UI.build_right_panel_definition()

				if not is_shop_preview() and G.GAME.pseudorandom.seed ~= nil then
					Showman.UI.render_result_page()
				end

				-- UI Menu --

				return {
					n = G.UIT.ROOT,
					config = {
						id = 'showman_ui_tab',
						r = 0.1,
						align = "mm",
						padding = 0.1,
						colour = G.C.CLEAR
					},
					nodes = {
 						{
							n = G.UIT.C,
							config = {
								colour = darken(G.C.UI.TRANSPARENT_DARK, 0.25),
								r = 0.1,
								padding = 0.1
							},
							nodes = {
								{
									n = G.UIT.R,
									config = {
										align = "tm",
										padding = 0.04
									},
									nodes = {
										{
											n = G.UIT.T,
											config = {
												text = "Seed Analysis",
												colour = G.C.BLACK,
												scale = 0.55
											}
										}
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "tm",
										padding = 0.02
									},
									nodes = {
										{
											n = G.UIT.T,
											config = {
												text = "Queue",
												colour = G.C.WHITE,
												scale = 0.4
											}
										}
									}
								},
 								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.05
									},
									nodes = {
										create_option_cycle({
											id = 'queue_cycle_page',
											options = Showman.antes,
											w = 4,
											h = 0.3,
											cycle_shoulders = true,
											opt_callback = "change_search_queue",
											current_option = Showman.config.SEEK.search_queueID or 1,
											colour = G.C.PURPLE,
											--no_pips = true,
											focus_args = {snap_to = true, nav = 'wide'}
										})
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.05
									},
									nodes = {
										create_option_cycle({
											label = "Search Depth",
											w = 4,
											options = analyzeMax,
											opt_callback = "change_search_depth",
											colour = G.C.PURPLE,
											current_option = Showman.config.SEEK.search_depthID or 1
										})
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.05
									},
									nodes = {
										create_toggle({
											label = "Apply Showman?",
											ref_table = Showman.config.SEEK,
											ref_value = "apply_showman",
											current_option = Showman.config.SEEK.apply_showman or 0,
											callback = function(_set_toggle)
												Showman.config.SEEK.apply_showman = _set_toggle
												Showman.writeConfig()
											end
										})
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.05
									},
									nodes = {
										create_option_cycle({
											label = "RNG Model",
											w = 4,
											options = Showman.rng_model_options,
											opt_callback = "change_rng_model",
											colour = G.C.PURPLE,
											current_option = rng_model_option_index()
										})
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.06
									},
									nodes = {
										{n=G.UIT.C, config={align = "cm"}, nodes = {
											UIBox_button({
												button = 'set_to_current_ante',
												label = {"Set to Current Ante"},
												colour = G.C.PURPLE
											})
										}},
										{n=G.UIT.C, config={align = "cm"}, nodes = {
											UIBox_button({
												button = 'analyze',
												label = {"Analyze"},
												colour = G.C.RED
											})
										}}
									}
								}
							}
						},
 						{
							n = G.UIT.C,
							config = {
								align = "cm",
								padding  = 0.1,
								r = 0.1,
								colour = darken(G.C.UI.TRANSPARENT_DARK, 0.25)
							},
							nodes = {
								{n=G.UIT.O, config={id = 'showman_right_slot', object = UIBox{definition = right_panel_definition, config = {offset = {x=0,y=0}}}}}
							}
						}
 					}
				}
			end,
			tab_definition_function_args = "Showman"
		}
	end
	return ct(args)
end

Showman.ui_jokers = {}
Showman.ui_editions = {}
Showman.ui_stickers = {}

Showman.ui.last_page = nil

G.FUNCS.showman_ui_joker_page_update = function(e)
	e.config.current_option = Showman.ui_search_page
end

G.FUNCS.showman_ui_joker_page = function(args)
    if not args or not args.cycle_config then return end
	if G.STAGE ~= G.STAGES.RUN then return end
	-- This cycle isn't even present in the Shop Preview tree, so this
	-- shouldn't be reachable while it's selected - defensive guard anyway,
	-- matching G.FUNCS.analyze's (see its comment for why).
	if is_shop_preview() then return end
	Showman.ui_search_page = args.cycle_config.current_option

	Showman.UI.clear_result_cards()
	Showman.UI.render_result_page()
end
