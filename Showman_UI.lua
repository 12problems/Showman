local lovely = require("lovely")
local nativefs = require("nativefs")

local searchTagKeys = {"None", "Charm Tag", "Double Tag", "Uncommon Tag", "Rare Tag", "Holographic Tag", "Foil Tag", "Polychrome Tag", "Investment Tag", "Voucher Tag", "Boss Tag", "Juggle Tag", "Coupon Tag", "Economy Tag", "Skip Tag", "D6 Tag"}
local searchPackKeys = {"None", "Arcana", "Celestial", "Standard", "Buffoon", "Spectral", "Normal Arcana", "Jumbo Arcana", "Mega Arcana", "Normal Celestial", "Jumbo Celestial", "Mega Celestial", "Normal Standard", "Jumbo Standard", "Mega Standard", "Normal Buffoon", "Jumbo Buffoon", "Mega Buffoon", "Normal Spectral", "Jumbo Spectral", "Mega Spectral"}

Showman.SEEK.scale = 0.7
Showman.SEEK.row_count = 4
Showman.SEEK.card_count = 6

local analyzeMax = {100, 1000, 10000}

--Showman.config.SEEK = {}
--Showman.config.SEEK.search_ante = 1

G.FUNCS.change_search_ante = function(x)
	Showman.config.SEEK.search_ante = x.to_val
	--sendDebugMessage("changed change_search_ante to "..Showman.config.SEEK.search_ante)
	Showman.writeConfig()
end

G.FUNCS.change_search_depth = function(x)
	Showman.config.SEEK.search_depth = x.to_val
	Showman.config.SEEK.search_depthID = x.to_key
	--sendDebugMessage("changed change_search_depth to "..x.to_val)
	Showman.writeConfig()
end

G.FUNCS.set_to_current_ante = function(x)
	if G.STAGE == G.STAGES.RUN then
		Showman.config.SEEK.search_ante = G.GAME.round_resets.ante
		Showman.writeConfig()
		--G.OVERLAY_MENU:recalculate()
		--G.OVERLAY_MENU:get_UIE_by_ID('ante_cycle_page').config.current_option = Showman.config.SEEK.search_ante
	end
end

Showman.ui = {}
--Showman.ui.page_cycle = nil
--Showman.ui.ante_cycle = nil

G.FUNCS.analyze = function(x)
	local out = ""
	local cards = {}
	local editions = {}
	for j = 1, #Showman.ui_card_area do
		for i = #Showman.ui_card_area[j].cards,1, -1 do
			if Showman.ui_card_area[j].cards[i] == nil then goto continuee end
			local c = Showman.ui_card_area[j]:remove_card(Showman.ui_card_area[j].cards[i])
			c:remove()
			c = nil
			::continuee::
		end
	end
	if G.STAGE == G.STAGES.RUN then
		G.SETTINGS.paused = true

		Showman.joker_options = {}
		for i = 1, math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*#Showman.ui_card_area)) do
			table.insert(Showman.joker_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*#Showman.ui_card_area))))
		end
		out, cards, editions = generateShopAnte(Showman.config.SEEK.search_depth, Showman.config.SEEK.search_ante)
		--.current_option = 1
		--G.OVERLAY_MENU:get_UIE_by_ID('showman_joker_page').current_option = 1
		Showman.ui_jokers = cards
		Showman.ui_editions = editions
		Showman.ui_search_page = 1
		for i = 1, Showman.SEEK.card_count do
			for j = 1, #Showman.ui_card_area do
				local center = nil
				for kk, vv in pairs(G.P_CENTERS) do
					if vv.name == nil then goto continue end
					b = false
					--sendDebugMessage("%% - "..vv.name)
					if vv.name == cards[(i+(j-1)*Showman.SEEK.card_count)-1] then
						center = vv
						b = true
						--sendDebugMessage("$$$ - "..vv.name.." found")
						break
					end
					if b then break end
					::continue::
				end
				if not center then 
					--sendDebugMessage("no center found % "..cards[i+(j-1)*Showman.SEEK.card_count])
					break
				end
				local card = Card(Showman.ui_card_area[j].T.x + Showman.ui_card_area[j].T.w/2, Showman.ui_card_area[j].T.y, G.CARD_W*Showman.SEEK.scale, G.CARD_H*Showman.SEEK.scale, nil, center)
				local edition = editions[(i+(j-1)*Showman.SEEK.card_count + (Showman.SEEK.card_count*#Showman.ui_card_area*(Showman.ui_search_page - 1)))-1]
				if edition == "Foil" then edition = {foil = true} 
				elseif edition == "Holo" then edition = {holo = true}
				elseif edition == "Polychrome" then edition = {polychrome = true}
				elseif edition == "Negative" then edition = {negative = true}
				else edition = nil end
				card:set_edition(edition, true, true)
				card.sticker = get_joker_win_sticker(center)
				Showman.ui_card_area[j]:emplace(card)
			end
		end
		--local tab = G.OVERLAY_MENU:get_UIE_by_ID('showman_ui_tab')
		--local a = tab.UIBox:get_UIE_by_ID('ante_cycle_page')
		--a.config.current_option = 1
		--a.UIBox:recalculate()
		--tab.UIBox:recalculate()
		--G.OVERLAY_MENU:recalculate()
	end
end

Showman.G_FUNCS_options_ref = G.FUNCS.options
G.FUNCS.options = function(e)
	Showman.G_FUNCS_options_ref(e)
end

local antes = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39}

Showman.ui_card_area = {}
Showman.joker_options = {}
Showman.deck_tables = {}
Showman.ui_search_page = 1

local ct = create_tabs
function create_tabs(args)
	if args and args.tab_h == 7.05 then
		args.tabs[#args.tabs + 1] = {
			label = "Showman",
			tab_definition_function = function()

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

				Showman.joker_options = {}
				for i = 1, math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*#Showman.ui_card_area)) do
					table.insert(Showman.joker_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(Showman.config.SEEK.search_depth/(Showman.SEEK.card_count*#Showman.ui_card_area))))
				end

				if G.GAME.pseudorandom.seed ~= nil then
					for i = 1, Showman.SEEK.card_count do
						for j = 1, #Showman.ui_card_area do
							local center = nil
							for kk, vv in pairs(G.P_CENTERS) do
								if vv.name == nil then goto continue end
								b = false
								--sendDebugMessage("%% - "..vv.name)
								if vv.name == Showman.ui_jokers[(i+(j-1)*Showman.SEEK.card_count + (Showman.SEEK.card_count*#Showman.ui_card_area*(Showman.ui_search_page - 1)))-1] then
									center = vv
									b = true
									--sendDebugMessage("$$$ - "..vv.name.." found")
									break
								end
								if b then break end
								::continue::
							end
							if not center then 
								--sendDebugMessage("no center found % "..Showman.ui_card_area[i+(j-1)*5])
								break
							end
							local card = Card(Showman.ui_card_area[j].T.x + Showman.ui_card_area[j].T.w/2, Showman.ui_card_area[j].T.y, G.CARD_W*Showman.SEEK.scale, G.CARD_H*Showman.SEEK.scale, nil, center)
							local edition = Showman.ui_editions[(i+(j-1)*Showman.SEEK.card_count + (Showman.SEEK.card_count*#Showman.ui_card_area*(Showman.ui_search_page - 1)))-1]
							if edition == "Foil" then 
								edition = {foil = true} 
							elseif edition == "Holo" then
								edition = {holo = true}
							elseif edition == "Polychrome" then 
								edition = {polychrome = true}
							elseif edition == "Negative" then 
								edition = {negative = true}
							else 
								edition = nil 
							end
							card:set_edition(edition, true, true)
							card.sticker = get_joker_win_sticker(center)
							Showman.ui_card_area[j]:emplace(card)
						end
					end
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
								padding = 0.15
							},
							nodes = {
								{
									n = G.UIT.R,
									config = {
										align = "tm"
									},
									nodes = {
										{
											n = G.UIT.T,
											config = {
												text = "Seed Analysis",
												colour = G.C.BLACK,
												scale = 0.6
											}
										}
									}
								},
 								{
									n = G.UIT.R,
									config = {
										align = "cm"
									},
									nodes = {
										create_option_cycle({
											id = 'ante_cycle_page',
											label = "Ante",
											w = 4,
											options = antes,
											no_pips = true,
											opt_callback = "change_search_ante",
											--func = 'change_search_func',
											colour = G.C.PURPLE,
											current_option = Showman.config.SEEK.search_ante or 1
										})
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm"
									},
									nodes = {
										{
											n = G.UIT.T,
											config = {
												text = "Hover for note",
												colour = G.C.BLACK,
												scale = 0.3,
												tooltip = {
													title = "Note",
													text = {
														"Does not update the number visually",
														"until the menu is reopened, but",
														"it still changes to the current ante"
													}
												}
											}
										}
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										color = G.C.CLEAR
									},
									nodes = {
										UIBox_button({
											button = 'set_to_current_ante',
											label = {"Set to Current Ante"},
											colour = G.C.PURPLE
										})
									}
								},
								{
									n = G.UIT.R,
									config = {
										align = "cm"
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
										align = "cm"
									},
									nodes = {
										create_toggle({
											label = "Apply Showman?",
											ref_table = Showman.config.SEEK,
											ref_value = "apply_showman",
											--colour = G.C.PURPLE,
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
									},
									nodes = {
										UIBox_button({
											button = 'analyze',
											label = {"Analyze"},
											colour = G.C.PURPLE
										})
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
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.02,
										r=0.1,
										colour = darken(G.C.UI.TRANSPARENT_DARK, 0.25)
									},
									nodes = Showman.deck_tables
								},
								{									
									n = G.UIT.R,
									config = {
										align = "cm",
										--func = "test_update_menu"
									},
									nodes = {
										create_option_cycle(
											{
												id = 'showman_joker_page',
												options = Showman.joker_options,
												w = 4,
												h = 0.3,
												cycle_shoulders = true, 
												opt_callback = 'showman_ui_joker_page',
												--func = 'showman_ui_joker_page_update',
												current_option = Showman.ui_search_page or 1,
												colour = G.C.PURPLE,
												no_pips = true,
												focus_args = {snap_to = true, nav = 'wide'}
											}
										)
									}
								}
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

Showman.ui.last_page = nil
G.FUNCS.test_update_menu = function(e)
	if not Showman.ui.last_page then
		Showman.ui.last_page = Showman.ui_search_page
		return
	end
	if Showman.ui.last_page ~= Showman.ui_search_page then
		--get the option cycle page
		local menu_uibox = e.config.object
		--get the parent
		local menu_wrap = menu_uibox.parent
		--delete current menu
		menu_wrap.config.object:remove()
		--crete new
		menu_wrap.config.object = UIBox({
			definition = create_option_cycle(
				{
					id = 'showman_joker_page',
					options = Showman.joker_options,
					w = 4,
					h = 0.3,
					cycle_shoulders = true, 
					opt_callback = 'showman_ui_joker_page',
					--func = 'showman_ui_joker_page_update',
					current_option = Showman.ui_search_page or 1,
					colour = G.C.PURPLE,
					no_pips = true,
					focus_args = {snap_to = true, nav = 'wide'}
				}
			),
			config = {
				parent = menu_wrap
			}
		})
		--update ui
		menu_wrap.UIBox:recalculate()


	end
end

function Showman.create_option_cycle_ante()
	local t = create_option_cycle({
		id = 'ante_cycle_page',
		label = "Ante",
		w = 4,
		options = antes,
		no_pips = true,
		opt_callback = "change_search_ante",
		func = 'change_search_func',
		colour = G.C.PURPLE,
		current_option = Showman.config.SEEK.search_ante or 1
	})

	--Showman.ui.ante_cycle = t
	return t
end

function Showman.create_option_cycle_joker_page()
	local t = create_option_cycle(
		{
			id = 'showman_joker_page',
			options = Showman.joker_options,
			w = 4,
			h = 0.3,
			cycle_shoulders = true, 
			opt_callback = 'showman_ui_joker_page', 
			func = 'showman_ui_joker_page_update',
			current_option = Showman.ui_search_page or 1, 
			colour = G.C.PURPLE,
			no_pips = true,
			focus_args = {snap_to = true, nav = 'wide'}
		}
	)
	--Showman.ui.page_cycle = t
	return t
end

G.FUNCS.showman_ui_joker_page_update = function(e)
	e.config.current_option = Showman.ui_search_page
	--e.UIBox:recalculate()
end

G.FUNCS.showman_ui_joker_page = function(args)
    if not args or not args.cycle_config then return end
	if G.STAGE ~= G.STAGES.RUN then return end
	Showman.ui_search_page = args.cycle_config.current_option

	for j = 1, #Showman.ui_card_area do
		for i = #Showman.ui_card_area[j].cards,1, -1 do
			local c = Showman.ui_card_area[j]:remove_card(Showman.ui_card_area[j].cards[i])
			c:remove()
			c = nil
		end
	end

    for i = 1, Showman.SEEK.card_count do
        for j = 1, #Showman.ui_card_area do
            local center = nil
			for kk, vv in pairs(G.P_CENTERS) do
				if vv.name == nil then goto continue end
				b = false
				--sendDebugMessage("%% - "..vv.name)
				if vv.name == Showman.ui_jokers[(i+(j-1)*Showman.SEEK.card_count + (Showman.SEEK.card_count*#Showman.ui_card_area*(args.cycle_config.current_option - 1)))-1] then
					center = vv
					b = true
					--sendDebugMessage("$$$ - "..vv.name.." found")
					break
				end
				if b then break end
				::continue::
			end
			if not center then 
				--sendDebugMessage("no center found % "..Showman.ui_card_area[i+(j-1)*5])
				break
			end
			local card = Card(Showman.ui_card_area[j].T.x + Showman.ui_card_area[j].T.w/2, Showman.ui_card_area[j].T.y, G.CARD_W*Showman.SEEK.scale, G.CARD_H*Showman.SEEK.scale, nil, center)
			local edition = Showman.ui_editions[(i+(j-1)*Showman.SEEK.card_count + (Showman.SEEK.card_count*#Showman.ui_card_area*(Showman.ui_search_page - 1)))-1]
			if edition == "Foil" then edition = {foil = true} 
			elseif edition == "Holo" then edition = {holo = true}
			elseif edition == "Polychrome" then edition = {polychrome = true}
			elseif edition == "Negative" then edition = {negative = true}
			else edition = nil end
			card:set_edition(edition, true, true)
			card.sticker = get_joker_win_sticker(center)
			Showman.ui_card_area[j]:emplace(card)
		end
    end
end