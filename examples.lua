----- EXAMPLE EFFECT TYPES -----

playereffects.register_effect_type("high_speed", "High speed", nil, {"speed"}, 
	function(player)
		player:set_physics_override(4,nil,nil)
	end,
	
	function(effect)
		local player = minetest.get_player_by_name(effect.playername)
		player:set_physics_override(1,nil,nil)
	end
)
playereffects.register_effect_type("low_speed", "Low speed", nil, {"speed"}, 
	function(player)
		player:set_physics_override(0.25,nil,nil)
	end,
	
	function(effect)
		local player = minetest.get_player_by_name(effect.playername)
		player:set_physics_override(1,nil,nil)
	end
)
playereffects.register_effect_type("highjump", "Greater jump height", "playereffects_example_highjump.png", {"jump"},
	function(player)
		player:set_physics_override(nil,2,nil)
	end,
	function(effect)
		local player = minetest.get_player_by_name(effect.playername)
		player:set_physics_override(nil,1,nil)
	end
)
playereffects.register_effect_type("fly", "Fly mode available", "playereffects_example_fly.png", {"fly"},
	function(player)
		local playername = player:get_player_name()
		local privs = minetest.get_player_privs(playername)
		privs.fly = true
		minetest.set_player_privs(playername, privs)
	end,
	function(effect)
		local privs = minetest.get_player_privs(effect.playername)
		privs.fly = nil
		minetest.set_player_privs(effect.playername, privs)
	end
)
playereffects.register_effect_type("stress", "Stress Test Effect", nil, {},
	function(player)
	end,
	function(effect)
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

minetest.register_chatcommand("fly", {
	params = "",
	description = "Grants you the fly privilege for a short time.",
	privs = {},
	func = function(name, param)
		playereffects.apply_effect_type("fly", 20, minetest.get_player_by_name(name))
	end,
})
minetest.register_chatcommand("stresstest", {
	params = "[<effects>]",
	descriptions = "Start the stress test for Player Effects with <effects> effects.",
	privs = {server=true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local max = 100
		if(type(param)=="string") then
			if(type(tonumber(param)) == "number") then
				max = tonumber(param)
				if(max > 1000) then max = 1000 end
			end
		end
		minetest.debug("[playereffects] Stress test started for "..name.." with "..max.." effects.")
		for i=1,max do
			playereffects.apply_effect_type("stress", 10, player)
		end
	end
})
