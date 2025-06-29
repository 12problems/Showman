Showman.SEEK = {}
Showman.SEEK.GAME = {}
Showman.SEEK.GAME.pseudorandom = {}
Showman.SEEK.GAME.pseudorandom.seed = 0
Showman.SEEK.GAME.pseudorandom.hashed_seed = 0


function generateShop(count)
	Showman.SEEK.ANTE = {}

	Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
	Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
	Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed
	endIndex = G.GAME.round_resets.ante
	for a=G.GAME.round_resets.ante, endIndex do
		output = ""
		cards = {}
		for i=0,count-1 do
			c, e = create_pseudocard_for_shop(a)
			if output ~= "" then output = output..", " end
			cards[count] = (e and e.." "..c or c)
			if(e == "" or e == nil) then
				output = output..(c)
			else
				output = output..(e).." "..(c)
			end
			--c.remove()
		end
		Showman.SEEK.ANTE[a] = cards
	end
	return output, cards
end

function generateShopAnte(count, ab)
	Showman.SEEK.ANTE = {}

	Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
	Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
	Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed
	endIndex = ab
	for a=ab, endIndex do
		output = ""
		cards = {}
        editions = {}
		for i=0,count-1 do
			c, e = create_pseudocard_for_shop(a)
			if output ~= "" then output = output..", " end
			cards[i] = Showman.trim(c)
            editions[i] = e
			if e == "" or e == nil then
				output = output..(c)
            elseif e == "Negative" then
                output = output.."** Negative ** "..(c)
            else
				output = output..(e).." "..(c)
			end
		end
		Showman.SEEK.ANTE[a] = cards
	end
	return output, cards, editions
end

function generateShopUntil(joker_name)
	Showman.SEEK.GAME.pseudorandom = shallowcopy(G.GAME.pseudorandom)
	Showman.SEEK.GAME.pseudorandom.seed = G.GAME.pseudorandom.seed
	Showman.SEEK.GAME.pseudorandom.hashed_seed = G.GAME.pseudorandom.hashed_seed
	
	c = ""
	e = ""
	count = 0
	output = ""
	cards = {}
	while c ~= joker_name and count < Showman.config.SEEK.search_depth do
		c, e = create_pseudocard_for_shop(G.GAME.round_resets.ante)
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

function create_pseudocard_for_shop(ante)
	local _center = G.P_CENTERS.c_empress
	local card = "" --Card(0, 0, 0, 0, G.P_CARDS.empty, _center, {bypass_discovery_center = true, bypass_discovery_ui = true})

	G.GAME.spectral_rate = G.GAME.spectral_rate or 0
	local total_rate = G.GAME.joker_rate + G.GAME.tarot_rate + G.GAME.planet_rate + G.GAME.playing_card_rate + G.GAME.spectral_rate
	local polled_rate = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('cdt'..ante))*total_rate
	local check_rate = 0
	local card = ""
	local edition = ""
	for _, v in ipairs({
	{type = 'Joker', val = G.GAME.joker_rate},
	{type = 'Tarot', val = G.GAME.tarot_rate},
	{type = 'Planet', val = G.GAME.planet_rate},
	{type = (G.GAME.used_vouchers["v_illusion"] and Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('illusion')) > 0.6) and 'Enhanced' or 'Base', val = G.GAME.playing_card_rate},
	{type = 'Spectral', val = G.GAME.spectral_rate},
	}) do
		if polled_rate > check_rate and polled_rate <= check_rate + v.val then
			card, edition = Showman.FUNC.create_card(v.type, nil, nil, nil, nil, nil, nil, 'sho', ante)
			if (v.type == 'Base' or v.type == 'Enhanced') and G.GAME.used_vouchers["v_illusion"] and Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('illusion')) > 0.8 then 
				local edition_poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed('illusion'))
				if edition_poll > 1 - 0.15 then edition = "Polychrome"
				elseif edition_poll > 0.5 then edition = "Holo"
				else edition = "Foil"
				end
			end
			return card, edition
		end
	check_rate = check_rate + v.val
	end
end

Showman.FUNC = {}

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

function Showman.FUNC.create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append, ante)
    local area = area or G.jokers
    local center = G.P_CENTERS.b_red

    --should pool be skipped with a forced key
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

    if forced_key and not G.GAME.banned_keys[forced_key] then 
        center = G.P_CENTERS[forced_key]
        _type = (center.set ~= 'Default' and center.set or _type)
    else
        local _pool, _pool_key = Showman.FUNC.get_current_pool(_type, _rarity, legendary, key_append, ante)
        center = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key))
        local it = 1
        while center == 'UNAVAILABLE' do
            it = it + 1
            center = Showman.FUNC.pseudorandom_element(_pool, Showman.FUNC.pseudoseed(_pool_key..'_resample'..it))
        end

        center = G.P_CENTERS[center]
    end

	local edition = ""
    if _type == 'Joker' then
        if G.GAME.modifiers.all_eternal then
            --card:set_eternal(true)
        end
        if (true) or (area == G.pack_cards) then 
            local eternal_perishable_poll = Showman.FUNC.pseudorandom((area == G.pack_cards and 'packetper' or 'etperpoll')..ante)
            if G.GAME.modifiers.enable_eternals_in_shop and eternal_perishable_poll > 0.7 then
                --card:set_eternal(true)
            elseif G.GAME.modifiers.enable_perishables_in_shop and ((eternal_perishable_poll > 0.4) and (eternal_perishable_poll <= 0.7)) then
                --card:set_perishable(true)
            end
            if G.GAME.modifiers.enable_rentals_in_shop and Showman.FUNC.pseudorandom((area == G.pack_cards and 'packssjr' or 'ssjr')..ante) > 0.7 then
                --card:set_rental(true)
            end
        end

        edition = Showman.FUNC.poll_edition('edi'..(key_append or '')..ante)
    end

	return center.name, edition
end

function Showman.FUNC.poll_edition(_key, _mod, _no_neg, _guaranteed)
    _mod = _mod or 1
    local edition_poll = Showman.FUNC.pseudorandom(Showman.FUNC.pseudoseed(_key or 'edition_generic'))
    if _guaranteed then
        if edition_poll > 1 - 0.003*25 and not _no_neg then
            return "Negative"
        elseif edition_poll > 1 - 0.006*25 then
            return "Nolychrome"
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
    return nil
end

function Showman.FUNC.get_current_pool(_type, _rarity, _legendary, _append, ante)
        --create the pool
        G.ARGS.TEMP_POOL = EMPTY(G.ARGS.TEMP_POOL)
        local _pool, _starting_pool, _pool_key, _pool_size = G.ARGS.TEMP_POOL, nil, '', 0
    
        if _type == 'Joker' then 
            local rarity = _rarity or Showman.FUNC.pseudorandom('rarity'..ante..(_append or '')) 
            rarity = (_legendary and 4) or (rarity > 0.95 and 3) or (rarity > 0.7 and 2) or 1
            _starting_pool, _pool_key = G.P_JOKER_RARITY_POOLS[rarity], 'Joker'..rarity..((not _legendary and _append) or '')
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

        return _pool, _pool_key..(not _legendary and ante or '')
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