--[[
	Title: x88Cheats
	Author: brokenw1nter (Discord: w1nter#4947)
	Version: 2.0.1
	Note: Started this at the beginning of this year to learn the basics of LUA for another API but now that I'm here,
		  I thought I would convert it then share it since I want to get some feedback on what I could do to improve my habits in LUA.
		  I'm also stupidly dumb and can not for the life of me figure out how to check for the things listed in "Bugs".
		  If you would like to help with this LUA, just let me know as I'm opened to anyone that wants to help perfect this LUA.
		  Also I don't write LUAs so I don't know much about the API so if there are more efficient ways of doing what I have done, please let me know.
	Changelog: Fixed "In Lobby" function
	Bugs: "HS Only" hasn't been implemented yet due to me not knowing how to get the value of some of the items in the menu.
		  "NoHands" doesn't check for Hands transparency, meaning it will display that it is on when you have Hands Chams enabled.
		  "Chams" doesn't display material being used due to me not knowing how to get the value of an unnamed combobox.
		  "MPoints" doesn't check or display anything also due to me not knowing how to get the value of the different comboboxes.
	Plans: Function for Enabling ESP when Dead
		   Function for loading visual settings to replicate @MasterLooser's
		   Make the GUI interactive rather than just being a huge indicator.
		   Making "Legit" and "SuperLegit" load preset settings, mainly to just turn off anything that would count as not Legit.
	Credits: Aviarita (GS) - Anti-Aim Angles
			 kopretinka (GS) - Spectators List
			 sshunko (GS) and Nulledcore (GH) - Helping with "In Lobby" Function
]]--

--------------------------------------------------------------------------------
-- Local Variables
--------------------------------------------------------------------------------
local ffi = require('ffi')
local surface = require('gamesense/surface')
local draw_text = surface.draw_text
local ffi_cast, ffi_cdef, ffi_typeof = ffi.cast, ffi.cdef, ffi.typeof
local maxplayers, realtime = globals.maxplayers, globals.realtime
local exec, create_interface, set_event_callback = client.exec, client.create_interface, client.set_event_callback
local get_all, get_classname, get_prop, is_alive, local_player, get_player_name
	= entity.get_all, entity.get_classname, entity.get_prop, entity.is_alive, entity.get_local_player, entity.get_player_name
local new_button, new_checkbox, new_label, new_slider = ui.new_button, ui.new_checkbox, ui.new_label, ui.new_slider
local get, set, ref = ui.get, ui.set, ui.reference
local abs, floor, fmod, sin = math.abs, math.floor, math.fmod, math.sin
local format, len, sub, insert = string.format, string.len, string.sub, table.insert

ffi_cdef[[
    typedef void*(__thiscall* get_client_entity_t)(void*, int);
]]

local raw_ent_list = create_interface('client_panorama.dll', 'VClientEntityList003')
local ent_list = ffi_cast(ffi_typeof('void***'), raw_ent_list)
local client_entity = ffi_cast('get_client_entity_t', ent_list[0][3])
local font = surface.create_font('Tahoma', 14, 700, {0x200})
local _, tpa_hotkey = ref('VISUALS', 'Effects', 'Force third person (alive)')

--------------------------------------------------------------------------------
-- Menu
--------------------------------------------------------------------------------
-- Incase you want to change where the options are without c&p-ing, thank me later lol
local tab = 'LUA'
local box = 'B'

local lua_start = new_label(tab, box, '~~~~~~~~~~[x88Cheats]~~~~~~~~~~')
local enabled = new_checkbox(tab, box, 'Enabled')
local in_lobby = new_checkbox(tab, box, 'In Lobby')
local base_x = new_slider(tab, box, 'Menu X Position', 0, 1500, 300, true, 'px', 1)
local base_y = new_slider(tab, box, 'Menu Y Position', 0, 750, 7, true, 'px', 1)
local reset_base = new_button(tab, box, 'Reset Menu Position', function()
	set(base_x, 300)
	set(base_y, 7)
end)
local lua_split = new_label(tab, box, '~~~~~~~~~~~[Extras]~~~~~~~~~~~~')
local tp_dead = new_checkbox(tab, box, 'TP Dead Key')
local hs_only = new_checkbox(tab, box, 'Headshot Only')
local spec_list = new_checkbox(tab, box, 'Spectators List')
local spec_x = new_slider(tab, box, 'Spectators X Position', 0, 1800, 1400, true, 'px', 1)
local spec_y = new_slider(tab, box, 'Spectators Y Position', 0, 900, 7, true, 'px', 1)
local reset_spec = new_button(tab, box, 'Reset Spectators Position', function()
	set(spec_x, 1400)
	set(spec_y, 7)
end)
local lua_end = new_label(tab, box, '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')

--------------------------------------------------------------------------------
-- Feature Functions
--------------------------------------------------------------------------------
local function thirdperson_dead()
	local tpd_checkbox = ref('VISUALS', 'Effects', 'Force third person (dead)')
	if (get(tpa_hotkey)) then
		set(tpd_checkbox, true)
	else
		set(tpd_checkbox, false)
	end
end

local function headshot_only()
	
end

-- Pasted from @kopretinka because I'm too dumb to fix my own xD
local function spectators_list()
	local spectators = {}
	local my_spectators = {}
	
	for index = 1, maxplayers() do
		if (get_classname(index) == 'CCSPlayer') then
			local observer_target = get_prop(index, 'm_hObserverTarget')
			if (observer_target ~= nil) then
				if (spectators[observer_target] == nil) then
					spectators[observer_target] = {}
				end
				insert(spectators[observer_target], index)
			end
		end
	end
	
	if (spectators[local_player()] ~= nil) then
		for index = 1, #spectators[local_player()] do
			local name = get_player_name(spectators[local_player()][index])
			if (len(name) > 20) then
				name = sub(name, 1, 15)
			end
			my_spectators[index] = name
		end
	end
	
	if (spectators[local_player()] ~= nil) then
		for index = 1, #my_spectators do
			draw_text(get(spec_x), get(spec_y) - 15 + (index * 15), 62, 255, 255, 255, font, format("%s", my_spectators[index]))
		end
	end
end

--------------------------------------------------------------------------------
-- Menu Functions
--------------------------------------------------------------------------------
local function dec_hex(IN)
    local B, K, OUT, I, D = 16, '0123456789ABCDEF', '', 0
    while (IN > 0) do
        I = I + 1
        IN, D = floor(IN/B), fmod(IN, B) + 1
        OUT = sub(K, D, D)..OUT
    end
    return OUT
end

local function esp_checker()
	if (get(ref('VISUALS', 'Player ESP', 'Activation type')) == true) then
		if (get(ref('VISUALS', 'Player ESP', 'Teammates')) or get(ref('VISUALS', 'Player ESP', 'Dormant'))
			or get(ref('VISUALS', 'Player ESP', 'Bounding box')) or get(ref('VISUALS', 'Player ESP', 'Health bar'))
			or get(ref('VISUALS', 'Player ESP', 'Name')) or get(ref('VISUALS', 'Player ESP', 'Flags'))
			or get(ref('VISUALS', 'Player ESP', 'Weapon text')) or get(ref('VISUALS', 'Player ESP', 'Weapon icon'))
			or get(ref('VISUALS', 'Player ESP', 'Ammo')) or get(ref('VISUALS', 'Player ESP', 'Distance'))
			or get(ref('VISUALS', 'Player ESP', 'Glow')) or get(ref('VISUALS', 'Player ESP', 'Visualize aimbot'))
			or get(ref('VISUALS', 'Player ESP', 'Visualize aimbot (safe point)')) or get(ref('VISUALS', 'Player ESP', 'Line of sight'))
			or get(ref('VISUALS', 'Player ESP', 'Money')) or get(ref('VISUALS', 'Player ESP', 'Skeleton'))) then
		return true else return false end
	return true else return false end
end

local function super_legit_checker()
	if (get(ref('RAGE', 'Aimbot', 'Enabled')) or get(ref('RAGE', 'Other', 'Remove recoil'))
		or get(ref('RAGE', 'Other', 'Duck peek assist'))) then
	has_rage = true else has_rage = false end
	
	if (get(ref('AA', 'Anti-aimbot angles', 'Enabled'))) then
		if (get(ref('AA', 'Anti-aimbot angles', 'Pitch')) ~= 'Off' or get(ref('AA', 'Anti-aimbot angles', 'Yaw base')) ~= 'Local view'
			or get(ref('AA', 'Anti-aimbot angles', 'Yaw')) ~= 'Off' or get(ref('AA', 'Anti-aimbot angles', 'Freestanding body yaw'))
			or get(ref('AA', 'Anti-aimbot angles', 'Edge yaw')) or get(ref('AA', 'Anti-aimbot angles', 'Body yaw')) ~= 'Off'
			or get(ref('AA', 'Anti-aimbot angles', 'Lower body yaw target')) ~= 'Off') then
		has_aa = true else has_aa = false end
	else has_aa = false end
	
	if (get(ref('AA', 'Fake lag', 'Enabled'))) then
	has_fakelag = true else has_fakelag = false end
	
	if (get(ref('VISUALS', 'Other ESP', 'Radar')) or get(ref('VISUALS', 'Other ESP', 'Grenades'))
		or get(ref('VISUALS', 'Other ESP', 'Bomb')) or get(ref('VISUALS', 'Other ESP', 'Upgrade tablet'))
		or get(ref('VISUALS', 'Effects', 'Remove flashbang effects')) or get(ref('VISUALS', 'Effects', 'Remove smoke grenades'))
		or get(ref('VISUALS', 'Effects', 'Remove fog')) or get(ref('VISUALS', 'Effects', 'Remove scope overlay'))
		or get(ref('VISUALS', 'Effects', 'Instant scope')) or get(ref('VISUALS', 'Effects', 'Bullet tracers'))
		or get(ref('VISUALS', 'Colored models', 'Player behind wall')))
	then has_other_esp = true else has_other_esp = false end
	
	if (get(ref('MISC', 'Miscellaneous', 'Override FOV')) > 90 or get(ref('MISC', 'Movement', 'Standalone quick stop'))
		or get(ref('MISC', 'Movement', 'Infinite duck')) or get(ref('MISC', 'Movement', 'Air strafe'))
		or get(ref('MISC', 'Movement', 'No fall damage')) or get(ref('MISC', 'Movement', 'Air duck')) ~= 'Off')
	then has_misc = true else has_misc = false end
	
	if (esp_checker() == false and has_rage == false and has_aa == false and has_fakelag == false
		and has_other_esp == false and has_misc == false) then
	return true else return false end
end

local function header()
	local user_name = panorama.open().MyPersonaAPI.GetName()
	local co_owner = 'tydoo'
	draw_text(get(base_x), get(base_y), 255, 255, 125, 255, font, 'Hello '..user_name..' :)')
	draw_text(get(base_x), get(base_y) + 15, 255, 255, 125, 255, font, 'Hello '..co_owner..' :)')
	draw_text(10, 52, 255, 62, 62, 255, font, 'x88Cheats')
end

local function sub_header()
	if (local_player()) then
		local lp_address = ffi_cast('int*', client_entity(ent_list, local_player()))[0]
		draw_text(get(base_x) + 100, get(base_y) + 14, 255, 255, 125, 255, font, 'LocalPlayer '..dec_hex(lp_address))
		
		local lby_angle = get_prop(local_player(), 'm_flLowerBodyYawTarget')
		local pitch_angle, yaw_angle, other_angle = get_prop(local_player(), 'm_angEyeAngles')
		local diff_angle = abs(lby_angle - yaw_angle)
		
		if (get(ref('AA', 'Anti-aimbot angles', 'Enabled'))) then
			draw_text(get(base_x), get(base_y) + 30, 255, 255, 125, 255, font, 'Fake: '..tostring(floor(lby_angle))..'.0')
			draw_text(get(base_x) + 100, get(base_y) + 30, 255, 255, 125, 255, font, 'Real: '..tostring(floor(yaw_angle))..'.0')
			draw_text(get(base_x) + 200, get(base_y) + 30, 62, 255, 62, 255, font, 'Diff: '..tostring(floor(diff_angle))..'.0')
		end
	else
		draw_text(get(base_x) + 100, get(base_y) + 14, 255, 255, 125, 255, font, 'LocalPlayer ')
	end
end

local function left_panel()
	-- TriggerBot Option --
	draw_text(get(base_x), get(base_y) + 45, 255, 255, 255, 255, font, 'TriggerBot:')
	if (get(ref('LEGIT', 'Triggerbot', 'Enabled'))) then
		draw_text(get(base_x) + 100, get(base_y) + 45, 62, 62, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 45, 255, 255, 255, 255, font, 'OFF') end
	
	-- BunnyHop Option --
	draw_text(get(base_x), get(base_y) + 60, 255, 255, 255, 255, font, 'BunnyHop:')
	if (get(ref('MISC', 'Movement', 'Bunny hop'))) then
		draw_text(get(base_x) + 100, get(base_y) + 60, 62, 62, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 60, 255, 255, 255, 255, font, 'OFF') end
	
	-- Chams Option --
	draw_text(get(base_x), get(base_y) + 75, 255, 255, 255, 255, font, 'Chams:')
	if (get(ref('VISUALS', 'Colored models', 'Player'))
	and get(ref('VISUALS', 'Colored models', 'Player behind wall')) ~= true) then
		draw_text(get(base_x) + 100, get(base_y) + 75, 62, 62, 255, 255, font, 'V_Default')
	elseif (get(ref('VISUALS', 'Colored models', 'Player behind wall'))) then
		draw_text(get(base_x) + 100, get(base_y) + 75, 255, 62, 62, 255, font, 'F_Default')
	else draw_text(get(base_x) + 100, get(base_y) + 75, 255, 255, 255, 255, font, 'OFF') end
	
	-- ESP Option --
	draw_text(get(base_x), get(base_y) + 90, 255, 255, 255, 255, font, 'ESP:')
	if (esp_checker()) then
		draw_text(get(base_x) + 100, get(base_y) + 90, 62, 62, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 90, 255, 255, 255, 255, font, 'OFF') end
	
	-- RankESP Option --
	draw_text(get(base_x), get(base_y) + 105, 255, 255, 255, 255, font, 'RankESP:')
	if (get(ref('MISC', 'Miscellaneous', 'Reveal competitive ranks'))) then
		draw_text(get(base_x) + 100, get(base_y) + 105, 62, 62, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 105, 255, 255, 255, 255, font, 'OFF') end
	
	-- NoHands Option --
	draw_text(get(base_x), get(base_y) + 120, 255, 255, 255, 255, font, 'NoHands:')
	if (get(ref('VISUALS', 'Colored models', 'Hands'))) then
		draw_text(get(base_x) + 100, get(base_y) + 120, 62, 62, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 120, 255, 255, 255, 255, font, 'OFF') end
	
	-- AA Option --
	draw_text(get(base_x), get(base_y) + 135, 255, 255, 255, 255, font, 'AA:')
	local r = floor(sin(realtime() * 1) * 127 + 128)
	local g = floor(sin(realtime() * 1 + 2) * 127 + 128)
	local b = floor(sin(realtime() * 1 + 4) * 127 + 128)
	if (get(ref('AA', 'Anti-aimbot angles', 'Enabled'))) then
		draw_text(get(base_x) + 100, get(base_y) + 135, r, g, b, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 135, 255, 255, 255, 255, font, 'OFF') end
	
	-- AA Mode Option --
	draw_text(get(base_x), get(base_y) + 150, 255, 255, 255, 255, font, 'AA Mode:')
	if (get(ref('AA', 'Anti-aimbot angles', 'Enabled'))) then
		if (get(ref('AA', 'Anti-aimbot angles', 'Body yaw')) == 'Opposite') then
			draw_text(get(base_x) + 100, get(base_y) + 150, 255, 255, 255, 255, font, 'Opposite')
		elseif (get(ref('AA', 'Anti-aimbot angles', 'Body yaw')) == 'Jitter') then
			draw_text(get(base_x) + 100, get(base_y) + 150, 255, 255, 255, 255, font, 'Jitter')
		elseif (get(ref('AA', 'Anti-aimbot angles', 'Body yaw')) == 'Static') then
			draw_text(get(base_x) + 100, get(base_y) + 150, 255, 255, 255, 255, font, 'Static')
		else draw_text(get(base_x) + 100, get(base_y) + 150, 255, 255, 255, 255, font, 'OFF') end
	else draw_text(get(base_x) + 100, get(base_y) + 150, 255, 255, 255, 255, font, 'OFF') end
	
	-- AA Pitch Offset --
	-- Honestly not even sure if this is supposed to be the pitch offset but it's something lol
	if (local_player() and get(ref('AA', 'Anti-aimbot angles', 'Enabled'))) then
		local pitch_angle, yaw_angle, other_angle = get_prop(local_player(), 'm_angEyeAngles')
		draw_text(get(base_x) + 230, get(base_y) + 150, 62, 255, 255, 255, font, tostring(floor(pitch_angle))..'.0')
	else draw_text(get(base_x) + 230, get(base_y) + 150, 62, 255, 255, 255, font, '0.0') end
	
	-- Clantag Option --
	draw_text(get(base_x), get(base_y) + 165, 255, 255, 255, 255, font, 'Clantag:')
	if (get(ref('MISC', 'Miscellaneous', 'Clan tag spammer'))) then
		draw_text(get(base_x) + 100, get(base_y) + 165, 62, 62, 255, 255, font, '1')
	else draw_text(get(base_x) + 100, get(base_y) + 165, 255, 255, 255, 255, font, '0') end
	
	-- Trickshot Option --
	draw_text(get(base_x), get(base_y) + 180, 255, 255, 255, 255, font, 'Trickshot:')
	if (get(ref('MISC', 'Settings', 'Hide from OBS'))) then
		draw_text(get(base_x) + 100, get(base_y) + 180, 62, 62, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 100, get(base_y) + 180, 255, 255, 255, 255, font, 'OFF') end
	
	-- FOVChanger Option --
	local fov = ref('MISC', 'Miscellaneous', 'Override FOV')
	draw_text(get(base_x), get(base_y) + 195, 255, 255, 255, 255, font, 'FOVChanger:')
	if (get(fov) > 90 or get(fov) < 90) then
		local fov = tostring(get(ref('MISC', 'Miscellaneous', 'Override FOV')))
		draw_text(get(base_x) + 100, get(base_y) + 195, 255, 255, 255, 255, font, fov)
	else draw_text(get(base_x) + 100, get(base_y) + 195, 255, 255, 255, 255, font, 'OFF') end
	
	-- Weapon FOV Option --
	draw_text(get(base_x), get(base_y) + 210, 255, 255, 255, 255, font, 'Weapon FOV:')
	local weapon_fov = cvar.viewmodel_fov
	draw_text(get(base_x) + 100, get(base_y) + 210, 255, 255, 255, 255, font, tostring(weapon_fov:get_int())..' N')
	
	-- Crosshair Option --
	draw_text(get(base_x), get(base_y) + 225, 255, 255, 255, 255, font, 'Crosshair:')
	if (get(ref('VISUALS', 'Other ESP', 'Crosshair'))) then
		draw_text(get(base_x) + 100, get(base_y) + 225, 62, 62, 255, 255, font, 'xhair')
	else draw_text(get(base_x) + 100, get(base_y) + 225, 255, 255, 255, 255, font, 'OFF') end
	
	-- pSilent Option --
	draw_text(get(base_x), get(base_y) + 240, 255, 255, 255, 255, font, 'pSilent:')
	if (get(ref('RAGE', 'Aimbot', 'Enabled'))) then
		if (get(ref('RAGE', 'Aimbot', 'Silent aim'))) then
			draw_text(get(base_x) + 100, get(base_y) + 240, 62, 62, 255, 255, font, 'Aim Override')
		else draw_text(get(base_x) + 100, get(base_y) + 240, 255, 255, 255, 255, font, 'OFF') end
	else draw_text(get(base_x) + 100, get(base_y) + 240, 255, 255, 255, 255, font, 'OFF') end
	
	-- AutoFire Option --
	draw_text(get(base_x), get(base_y) + 255, 255, 255, 255, 255, font, 'AutoFire:')
	if (get(ref('RAGE', 'Aimbot', 'Enabled'))) then
		if (get(ref('RAGE', 'Aimbot', 'Automatic fire'))) then
			draw_text(get(base_x) + 100, get(base_y) + 255, 62, 62, 255, 255, font, 'ON')
		else draw_text(get(base_x) + 100, get(base_y) + 255, 255, 255, 255, 255, font, 'OFF') end
	else draw_text(get(base_x) + 100, get(base_y) + 255, 255, 255, 255, 255, font, 'OFF') end
	
	-- HvH Mode Option --
	draw_text(get(base_x), get(base_y) + 270, 255, 255, 255, 255, font, 'HvH Mode:')
	if (get(ref('RAGE', 'Aimbot', 'Enabled'))) then
		draw_text(get(base_x) + 100, get(base_y) + 270, 62, 62, 255, 255, font, 'HvH (3)')
	else draw_text(get(base_x) + 100, get(base_y) + 270, 255, 255, 255, 255, font, 'OFF') end
	
	-- HS Only Option --
	draw_text(get(base_x), get(base_y) + 285, 255, 255, 255, 255, font, 'HS Only:')
	if (get(ref('RAGE', 'Aimbot', 'Enabled'))) then
		if (get(hs_only)) then
			draw_text(get(base_x) + 100, get(base_y) + 285, 62, 62, 255, 255, font, 'ON')
		else draw_text(get(base_x) + 100, get(base_y) + 285, 255, 255, 255, 255, font, 'OFF') end
	else draw_text(get(base_x) + 100, get(base_y) + 285, 255, 255, 255, 255, font, 'OFF') end
end

local function right_panel()
	-- MPoints Option --
	-- MasterLooser DOESN'T USE THIS SO IT'S NOT A THING DUH!
	draw_text(get(base_x) + 150, get(base_y) + 45, 255, 255, 255, 255, font, 'MPoints:')
	draw_text(get(base_x) + 230, get(base_y) + 45, 255, 255, 255, 255, font, '0   OFF')
	
	-- Legit Option --
	draw_text(get(base_x) + 150, get(base_y) + 60, 255, 255, 255, 255, font, 'Legit:')
	if (get(ref('RAGE', 'Aimbot', 'Enabled')) == false) then
		draw_text(get(base_x) + 230, get(base_y) + 60, 62, 255, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 230, get(base_y) + 60, 255, 255, 255, 255, font, 'OFF') end
	
	-- Thirdp Option --
	draw_text(get(base_x) + 174, get(base_y) + 75, 255, 255, 255, 255, font, 'Thirdp:')
	if (get(tpa_hotkey)) then
		local tp_dist = tostring(get(ref('MISC', 'Miscellaneous', 'Override FOV')))
		draw_text(get(base_x) + 254, get(base_y) + 75, 62, 62, 255, 255, font, 'ON '..tp_dist)
	else draw_text(get(base_x) + 254, get(base_y) + 75, 255, 255, 255, 255, font, 'OFF') end
	
	-- BackTrack Option --
	draw_text(get(base_x) + 150, get(base_y) + 90, 255, 255, 255, 255, font, 'BackTrack:')
	if (get(ref('RAGE', 'Aimbot', 'Enabled'))) then
		if (get(ref('RAGE', 'Other', 'Accuracy boost')) ~= 'Off') then
			draw_text(get(base_x) + 254, get(base_y) + 90, 62, 255, 255, 255, font, 'LBY')
		else draw_text(get(base_x) + 254, get(base_y) + 90, 255, 255, 255, 255, font, 'OFF') end
	elseif (get(ref('LEGIT', 'Aimbot', 'Enabled'))) then
		if (get(ref('LEGIT', 'Other', 'Accuracy boost')) ~= 'Off') then
			draw_text(get(base_x) + 254, get(base_y) + 90, 62, 255, 255, 255, font, 'Legit')
		else draw_text(get(base_x) + 254, get(base_y) + 90, 255, 255, 255, 255, font, 'OFF') end
	else draw_text(get(base_x) + 254, get(base_y) + 90, 255, 255, 255, 255, font, 'OFF') end
	
	-- BTChams Option --
	draw_text(get(base_x) + 150, get(base_y) + 105, 255, 255, 255, 255, font, 'BTChams:')
	if (get(ref('VISUALS', 'Colored models', 'Shadow'))) then
		draw_text(get(base_x) + 230, get(base_y) + 105, 62, 255, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 230, get(base_y) + 105, 255, 255, 255, 255, font, 'OFF') end
	
	-- AntiTrig Option --
	draw_text(get(base_x) + 150, get(base_y) + 120, 255, 255, 255, 255, font, 'AntiTrig:')
	if (get(ref('AA', 'Fake lag', 'Enabled'))) then
		draw_text(get(base_x) + 230, get(base_y) + 120, 62, 255, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 230, get(base_y) + 120, 255, 255, 255, 255, font, 'OFF') end
	
	-- SuperLegit Option --
	draw_text(get(base_x) + 150, get(base_y) + 135, 255, 255, 255, 255, font, 'SuperLegit:')
	if (super_legit_checker()) then
		draw_text(get(base_x) + 230, get(base_y) + 135, 62, 255, 255, 255, font, 'ON')
	else draw_text(get(base_x) + 230, get(base_y) + 135, 255, 255, 255, 255, font, 'OFF') end
end

local function stats()
	-- Grabs Stats if Player is in a Game
	if (local_player()) then
		local player_resource = get_all('CCSPlayerResource')[1]
		local kills = get_prop(player_resource, 'm_iKills', local_player())
		local deaths = get_prop(player_resource, 'm_iDeaths', local_player())
		local ping = get_prop(player_resource, 'm_iPing', local_player())
		
		-- Calculates Kills/Deaths Ratio
		local kd_ratio = ''
		if (deaths > 0) then kd_ratio = format('%.2f', (kills/deaths))
		else kd_ratio = format('%.2f', kills/1) end
		
		-- Prints Stats
		draw_text(get(base_x) + 150, get(base_y) + 165, 255, 255, 255, 255, font, 'Kills: '..kills)
		draw_text(get(base_x) + 150, get(base_y) + 180, 255, 255, 255, 255, font, 'Deaths: '..deaths)
		draw_text(get(base_x) + 150, get(base_y) + 195, 62, 255, 62, 255, font, 'KD: '..kd_ratio)
		draw_text(get(base_x) + 150, get(base_y) + 210, 255, 255, 255, 255, font, 'Ping: '..ping)
	else
		-- Prints Stats
		draw_text(get(base_x) + 150, get(base_y) + 165, 255, 255, 255, 255, font, 'Kills: 0')
		draw_text(get(base_x) + 150, get(base_y) + 180, 255, 255, 255, 255, font, 'Deaths: 0')
		draw_text(get(base_x) + 150, get(base_y) + 195, 62, 255, 62, 255, font, 'KD: 0.00')
		draw_text(get(base_x) + 150, get(base_y) + 210, 255, 255, 255, 255, font, 'Ping: 0')
	end
end

local function main()
	if (get(in_lobby) or local_player()) then
		header()
		sub_header()
		left_panel()
		right_panel()
		stats()
	else header() end
end

--------------------------------------------------------------------------------
-- Callbacks
--------------------------------------------------------------------------------
local function on_paint_ui()
	if (get(enabled)) then main() end
	if (get(tp_dead)) then thirdperson_dead() end
	if (get(hs_only)) then headshot_only() end
	if (get(spec_list)) then spectators_list() end
end

set_event_callback('paint_ui', on_paint_ui)