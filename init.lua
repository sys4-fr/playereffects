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

--[[ table (indexed by player names) containing tables containing the active HUD IDs for players
	Example: { ["Player 1"] = {1,2,3}, ["Player 2"] = {2}, ["Player 3"] = {} }
]]
playereffects.hudids = {}

-- Variable for counting the effect_id
playereffects.last_effect_id = 0

function playereffects.next_effect_id()
	playereffects.last_effect_id = playereffects.last_effect_id + 1
	return playereffects.last_effect_id
end

--[=[ API functions ]=]
function playereffects.register_effect_type(name, description, groups, apply, cancel)
	effect_type = {}
	effect_type.description = description
	effect_type.apply = apply
	effect_type.groups = groups
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
	local hudid = playereffects.hud_effect(effect_type_id, player, #playereffects.get_player_effects(playername))
	local effect = {
			playername = playername, 
			effect_id = effect_id,
			effect_type_id = effect_type_id,
			start_time = start_time,
			time_left = duration,
			hudid = hudid
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
		player:hud_remove(effect.hudid)
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
	playereffects.hudids[playername] = nil

	if(playereffects.inactive_effects[playername] == nil) then
		playereffects.inactive_effects[playername] = {}
	end
	for e=1,#effects do
		local start_time = effects[e].start_time
		local new_duration = os.difftime(leave_time, start_time)
		local new_effect = effects[e]
		new_effect.time_left = new_duration
		table.insert(playereffects.inactive_effects[playername], new_effect)
		playereffects.cancel_effect(effects[e].effect_id)
	end
end)


minetest.register_on_joinplayer(function(player)
	minetest.after(0, playereffects.join0, player)
end)

function playereffects.join0(player)
	local playername = player:get_player_name()

	-- load all the effects again (if any)
	if(playereffects.inactive_effects[playername] ~= nil) then
		for i=1,#playereffects.inactive_effects[playername] do
			local effect = playereffects.inactive_effects[playername][i]
			playereffects.apply_effect_type(effect.effect_type_id, effect.time_left, player)
		end
		playereffects.inactive_effects[playername] = nil
	end

end

--[[
minetest.register_on_shutdown(function()
	
end)
]]

--[=[ HUD ]=]
function playereffects.hud_update(player)
	playereffects.hud_clear(player)
	local effects = playereffects.get_player_effects(player:get_player_name())
	for e=1,#effects do
		playereffects.hud_effect(effects[e], player, e-1)
	end
end

function playereffects.hud_clear(player)
	local playername = player:get_player_name()
	local effects = playereffects.get_player_effects(playername)
	if(effects ~= nil) then
		for i=1,#effects do
			player:hud_remove(effects[i].hudid)
		end
	end
end

function playereffects.hud_effect(effect_type_id, player, pos)
	local id
	id = player:hud_add({
		hud_elem_type = "text",
		position = { x = 0.95, y = 0.3 },
		name = "effect_"..effect_type_id,
		text = playereffects.effect_types[effect_type_id].description,
		scale = { x = 20, y = 100},
		alignment = 1,
		direction = 1,
		number = 0xFFFFFF,
		offset = { x = 0, y = pos*20 } 
	})
	local playername = player:get_player_name()
	return id
end


----- EXAMPLE EFFECT TYPES -----

playereffects.register_effect_type("high_speed", "high speed", {"speed"}, 
	function(player)
		player:set_physics_override(4,nil,nil)
	end,
	
	function(effect)
		local player = minetest.get_player_by_name(effect.playername)
		player:set_physics_override(1,nil,nil)
	end
)
playereffects.register_effect_type("low_speed", "low speed", {"speed"}, 
	function(player)
		player:set_physics_override(0.25,nil,nil)
	end,
	
	function(effect)
		local player = minetest.get_player_by_name(effect.playername)
		player:set_physics_override(1,nil,nil)
	end
)
playereffects.register_effect_type("highjump", "greater jump height", {"jump"},
	function(player)
		player:set_physics_override(nil,2,nil)
	end,
	function(effect)
		local player = minetest.get_player_by_name(effect.playername)
		player:set_physics_override(nil,1,nil)
	end
)


minetest.register_chatcommand("fast", {
	params = "",
	description = "Makes you fast for a short time.",
	privs = {},
	func = function(name, param)
		playereffects.apply_effect_type("high_speed", 10, minetest.get_player_by_name(name))
	end,
})
minetest.register_chatcommand("slow", {
	params = "",
	description = "Makes you slow for a long time.",
	privs = {},
	func = function(name, param)
		playereffects.apply_effect_type("low_speed", 120, minetest.get_player_by_name(name))
	end,
})
minetest.register_chatcommand("highjump", {
	params = "",
	description = "Makes you jump higher for a short time.",
	privs = {},
	func = function(name, param)
		playereffects.apply_effect_type("highjump", 20, minetest.get_player_by_name(name))
	end,
})
