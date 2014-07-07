--[=[ Main tables ]=]

playereffects = {}

--[[ table containing the groups (experimental) ]]
playereffects.groups = {}

--[[ table containing all the effect types ]]
playereffects.effect_types = {}

--[[ table containing all the active effects ]]
playereffects.effects = {}

--[[ table containing all the inactive effects.
Effects become inactive if a player leaves an become active again if they join again. ]]
playereffects.inactive_effects = {}

-- Variable for counting the effect_id
playereffects.last_effect_id = 0

--[=[ Load inactive_effects and last_effect_id from playereffects.mt, if this file exists  ]=]
do
	local filepath = minetest.get_worldpath().."/playereffects.mt"
	local file = io.open(filepath, "r")
	local string
	if file then
		minetest.log("action", "[playereffects] playereffects.mt opened.")
		local string = file:read()
		io.close(file)
		if(string ~= nil) then
			savetable = minetest.deserialize(string)
			playereffects.inactive_effects = savetable.inactive_effects
			minetest.debug("[playereffects] playereffects.mt successfully read.")
			minetest.debug("[playereffects] inactive_effects = "..dump(playereffects.inactive_effects))
			playereffects.last_effect_id = savetable.last_effect_id
			minetest.debug("[playereffects] last_effect_id = "..dump(playereffects.last_effect_id))
			
		end
	end
end

function playereffects.next_effect_id()
	playereffects.last_effect_id = playereffects.last_effect_id + 1
	return playereffects.last_effect_id
end

--[=[ API functions ]=]
function playereffects.register_effect_type(name, description, icon, groups, apply, cancel)
	effect_type = {}
	effect_type.description = description
	effect_type.apply = apply
	effect_type.groups = groups
	effect_type.icon = icon
	if cancel ~= nil then
		effect_type.cancel = cancel
	else
		effect_type.cancel = function() end
	end
	playereffects.effect_types[name] = effect_type
	minetest.log("action", "Effect type "..name.." registered!")
end

function playereffects.apply_effect_type(effect_type_id, duration, player)
	local start_time = os.time()
	local playername = player:get_player_name()
	local groups = playereffects.effect_types[effect_type_id].groups
	for k,v in pairs(groups) do
		playereffects.cancel_effect_group(v, playername)
	end
	local effect_id = playereffects.next_effect_id()
	local effects = playereffects.get_player_effects(playername)
	local smallest_hudpos
	local biggest_hudpos = -1
	local free_hudpos
	for e=1,#effects do
		local hudpos = effects[e].hudpos
		if(hudpos > biggest_hudpos) then
			biggest_hudpos = hudpos
		end
		if(smallest_hudpos == nil) then
			smallest_hudpos = hudpos
		elseif(hudpos < smallest_hudpos) then
			smallest_hudpos = hudpos
		end
	end
	if(smallest_hudpos == nil) then
		free_hudpos = 0
	elseif(smallest_hudpos >= 0) then
		free_hudpos = smallest_hudpos - 1
	else
		free_hudpos = biggest_hudpos + 1
	end
	local hudids = playereffects.hud_effect(effect_type_id, player, free_hudpos, duration)

	local effect = {
			playername = playername, 
			effect_id = effect_id,
			effect_type_id = effect_type_id,
			start_time = start_time,
			time_left = duration,
			hudids = hudids,
			hudpos = free_hudpos,
			}

	playereffects.effects[effect_id] = effect
		
	playereffects.effect_types[effect_type_id].apply(player)
	minetest.log("action", "Effect type "..effect_type_id.." applied to player "..playername.."!")
	minetest.after(duration, function(effect_id) playereffects.cancel_effect(effect_id) end, effect_id)
end

-- TODO
function playereffects.cancel_effect_type(effect_type_id, playername)
end

function playereffects.cancel_effect_group(groupname, playername)
	local effects = playereffects.get_player_effects(playername)
	for e=1,#effects do
		local effect = effects[e]
		local thesegroups = playereffects.effect_types[effect.effect_type_id].groups
		minetest.log("action", "thesegroups = "..dump(thesegroups))
		minetest.log("action", "groupname = "..dump(groupname))
		local delete = false
		for g=1,#thesegroups do
			if(thesegroups[g] == groupname) then
				playereffects.cancel_effect(effect.effect_id)
				break
			end
		end
	end
end

function playereffects.cancel_effect(effect_id)
	local effect = playereffects.effects[effect_id]
	if(effect ~= nil) then
		local player = minetest.get_player_by_name(effect.playername)
		player:hud_remove(effect.hudids.text_id)
		if(effect.hudids.icon_id~=nil) then
			player:hud_remove(effect.hudids.icon_id)
		end
		playereffects.effect_types[effect.effect_type_id].cancel(effect)
		playereffects.effects[effect_id] = nil
		minetest.log("action", "Effect type "..effect.effect_type_id.." cancelled from player "..effect.playername.."!")
	end
end

function playereffects.get_player_effects(playername)
	if(minetest.get_player_by_name(playername) ~= nil) then
		local effects = {}
		for k,v in pairs(playereffects.effects) do
			if(v.playername == playername) then
				table.insert(effects, v)
			end
		end
		return effects
	else
		return {} 
	end
end

--[=[ Callbacks ]=]
--[[ Cancel all effects on player death ]]
minetest.register_on_dieplayer(function(player)
	local effects = playereffects.get_player_effects(player:get_player_name())
	for e=1,#effects do
		playereffects.cancel_effect(effects[e].effect_id)
	end
end)


minetest.register_on_leaveplayer(function(player)
	local leave_time = os.time()
	local playername = player:get_player_name()
	local effects = playereffects.get_player_effects(playername)

	playereffects.hud_clear(player)

	if(playereffects.inactive_effects[playername] == nil) then
		playereffects.inactive_effects[playername] = {}
	end
	for e=1,#effects do
		local new_duration = effects[e].time_left - os.difftime(leave_time, effects[e].start_time)
		local new_effect = effects[e]
		new_effect.time_left = new_duration
		table.insert(playereffects.inactive_effects[playername], new_effect)
		playereffects.cancel_effect(effects[e].effect_id)
	end
end)

minetest.register_on_shutdown(function()
	minetest.log("action", "[playereffects] Server shuts down. Rescuing data into playereffects.mt")
	local shutdown_time = os.time()
	local savetable = {}
	local effects = playereffects.effects
	local inactive_effects = playereffects.inactive_effects
	for id,effect in pairs(effects) do
		local new_duration = effect.time_left - os.difftime(shutdown_time, effect.start_time)
		local new_effect = effect
		new_effect.time_left = new_duration
		if(inactive_effects[effect.playername] == nil) then
			inactive_effects[effect.playername] = {}
		end
		table.insert(inactive_effects[effect.playername], new_effect)
		playereffects.cancel_effect(effect.effect_id)
	end

	savetable.inactive_effects = inactive_effects
	savetable.last_effect_id = playereffects.last_effect_id

	savestring = minetest.serialize(savetable)

	local filepath = minetest.get_worldpath().."/playereffects.mt"
	local file = io.open(filepath, "w")
	if file then
		file:write(savestring)
		io.close(file)
		minetest.log("action", "[playereffects] Wrote playereffects data into "..filepath..".")
	else
		minetest.log("error", "[playereffects] Failed to write playereffects data into "..filepath..".")
	end
	
end)

minetest.register_on_joinplayer(function(player)
	local playername = player:get_player_name()

	-- load all the effects again (if any)
	if(playereffects.inactive_effects[playername] ~= nil) then
		for i=1,#playereffects.inactive_effects[playername] do
			local effect = playereffects.inactive_effects[playername][i]
			playereffects.apply_effect_type(effect.effect_type_id, effect.time_left, player)
		end
		playereffects.inactive_effects[playername] = nil
	end
end)

playereffects.globalstep_timer = 0
minetest.register_globalstep(function(dtime)
	playereffects.globalstep_timer = playereffects.globalstep_timer + dtime
	if(playereffects.globalstep_timer < 1) then
		return
	end
	playereffects.globalstep_timer = 0

	local players = minetest.get_connected_players()
	for p=1,#players do
		playereffects.hud_update(players[p])
	end
end)




--[=[ HUD ]=]
function playereffects.hud_update(player)
	local now = os.time()
	local effects = playereffects.get_player_effects(player:get_player_name())
	for e=1,#effects do
		local effect = effects[e]
		local description = playereffects.effect_types[effect.effect_type_id].description
		local time_left = os.difftime(effect.start_time + effect.time_left, now)
		player:hud_change(effect.hudids.text_id, "text", description .. " ("..tostring(time_left).." s)")
	end
end

function playereffects.hud_clear(player)
	local playername = player:get_player_name()
	local effects = playereffects.get_player_effects(playername)
	if(effects ~= nil) then
		for e=1,#effects do
			player:hud_remove(effects[e].hudids.text_id)
			if(effects[e].hudids.icon_id ~= nil) then
				player:hud_remove(effects[e].hudids.icon_id)
			end
		end
	end
end

function playereffects.hud_effect(effect_type_id, player, pos, time_left)
	local text_id, icon_id
	text_id = player:hud_add({
		hud_elem_type = "text",
		position = { x = 1, y = 0.3 },
		name = "effect_"..effect_type_id,
		text = playereffects.effect_types[effect_type_id].description .. " ("..tostring(time_left).." s)",
		scale = { x = 170, y = 20},
		alignment = { x = -1, y = 0 },
		direction = 1,
		number = 0xFFFFFF,
		offset = { x = -5, y = pos*20 } 
	})
	if(playereffects.effect_types[effect_type_id].icon ~= nil) then
		icon_id = player:hud_add({
			hud_elem_type = "image",
			scale = { x = 1, y = 1 },
			position = { x = 1, y = 0.3 },
			name = "effect_icon_"..effect_type_id,
			text = playereffects.effect_types[effect_type_id].icon,
			alignment = { x = -1, y=0 },
			direction = 0,
			offset = { x = -186, y = pos*20 },
		})
	end	
	return { text_id = text_id, icon_id = icon_id }
end


-- LOAD EXAMPLES
dofile(minetest.get_modpath(minetest.get_current_modname()).."/examples.lua")
