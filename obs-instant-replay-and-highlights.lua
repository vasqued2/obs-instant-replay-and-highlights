obs               = obslua
source_name       = ""
vlc_name          = ""
scene_name        = ""
replaying         = false
autoclear         = false
addall            = false
replaylength      = 10
instant_hotkey_id = obs.OBS_INVALID_HOTKEY_ID
add_hotkey_id     = obs.OBS_INVALID_HOTKEY_ID
clear_hotkey_id   = obs.OBS_INVALID_HOTKEY_ID
attempts          = 0
current_path      = nil

----------------------------------------------------------

function set_current()
	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()
	if replay_buffer == nil then
		obs.remove_current_callback()
		return
	end
	local cd = obs.calldata_create()
	local ph = obs.obs_output_get_proc_handler(replay_buffer)
	obs.proc_handler_call(ph, "get_last_replay", cd)
	local path = obs.calldata_string(cd, "path")
	obs.calldata_destroy(cd)
	obs.obs_output_release(replay_buffer)
	current_path = path
end

function get_replay()
	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()
	if replay_buffer == nil then
		obs.remove_current_callback()
		return
	end

	-- Call the procedure of the replay buffer named "get_last_replay" to
	-- get the last replay created by the replay buffer
	local cd = obs.calldata_create()
	local ph = obs.obs_output_get_proc_handler(replay_buffer)
	obs.proc_handler_call(ph, "get_last_replay", cd)
	local path = obs.calldata_string(cd, "path")
	obs.calldata_destroy(cd)

	obs.obs_output_release(replay_buffer)
	if path ~= current_path then
		current_path = path
		return path
	else
		return nil
	end
end

function try_play()
	local path = get_replay()

	-- If the path is valid and the source exists, update it with the
	-- replay file to play back the replay.  Otherwise, stop attempting to
	-- replay after 10 seconds
	if path == nil then
		attempts = attempts + 1
		if attempts >= 100 then
			obs.remove_current_callback()
		end
	else
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "local_file", path)
			obs.obs_data_set_bool(settings, "is_local_file", true)
			obs.obs_data_set_bool(settings, "close_when_inactive", true)
			obs.obs_data_set_bool(settings, "restart_on_activate", true)

			-- updating will automatically cause the source to
			-- refresh if the source is currently active, otherwise
			-- the source will play whenever its scene is activated
			obs.obs_source_update(source, settings)

			obs.obs_data_release(settings)
			obs.obs_source_release(source)

			obs.timer_add(clear_instant, replaylength*1000)

			if addall then
				source = obs.obs_get_source_by_name(vlc_name)
				if source ~= nil then
					settings = obs.obs_source_get_settings(source)
					local playlist = obs.obs_data_get_array(settings, "playlist")
					local item = obs.obs_data_create()
					obs.obs_data_set_string(item, "value", path)
					obs.obs_data_array_push_back(playlist, item)
					obs.obs_data_set_array(settings, "playlist", playlist)

--					obs.obs_data_set_bool(settings, "loop", false)
--					obs.obs_data_set_bool(settings, "shuffle", false)
					obs.obs_data_set_string(settings, "playback_behavior", stop_restart)

					obs.obs_source_update(source, settings)

					obs.obs_data_release(item)
					obs.obs_data_array_release(playlist)
					obs.obs_data_release(settings)
					obs.obs_source_release(source)
				end
			end
		end

		obs.remove_current_callback()
	end
end

-- The "Instant Replay" hotkey callback
function instant_replay(pressed)
	if not pressed then
		return
	end

	set_current()

	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()
	if replay_buffer ~= nil then
		-- Call the procedure of the replay buffer named "get_last_replay" to
		-- get the last replay created by the replay buffer
		local ph = obs.obs_output_get_proc_handler(replay_buffer)
		obs.proc_handler_call(ph, "save", nil)

		-- Set a 1-second timer to attempt playback every 1 second
		-- until the replay is available
		if obs.obs_output_active(replay_buffer) then
			attempts = 0
			obs.timer_add(try_play, 100)
		else
			obs.script_log(obs.LOG_WARNING, "Tried to save an instant replay, but the replay buffer is not active!")
		end

		obs.obs_output_release(replay_buffer)
	else
		obs.script_log(obs.LOG_WARNING, "Tried to save an instant replay, but found no active replay buffer!")
	end
end

function clear_instant()
	local source = obs.obs_get_source_by_name(source_name)
	local settings = obs.obs_data_create()
	obs.obs_data_set_string(settings, "local_file", "")
	obs.obs_data_set_bool(settings, "is_local_file", true)
	obs.obs_data_set_bool(settings, "close_when_inactive", true)
	obs.obs_data_set_bool(settings, "restart_on_activate", true)
	obs.obs_source_update(source, settings)
	obs.obs_data_release(settings)
	obs.obs_source_release(source)
	obs.remove_current_callback()
end

function try_add()
	local path = get_replay()

	-- If the path is valid and the source exists, update it with the
	-- replay file to play back the replay.  Otherwise, stop attempting to
	-- replay after 10 seconds
	if path == nil then
		attempts = attempts + 1
		if attempts >= 100 then
			obs.remove_current_callback()
		end
	else
		local source = obs.obs_get_source_by_name(vlc_name)
		if source ~= nil then
			local settings = obs.obs_source_get_settings(source)
			local playlist = obs.obs_data_get_array(settings, "playlist")
			local item = obs.obs_data_create()
			obs.obs_data_set_string(item, "value", path)
			obs.obs_data_array_push_back(playlist, item)
			obs.obs_data_set_array(settings, "playlist", playlist)

--			obs.obs_data_set_bool(settings, "loop", false)
--			obs.obs_data_set_bool(settings, "shuffle", false)
			obs.obs_data_set_string(settings, "playback_behavior", stop_restart)

			obs.obs_source_update(source, settings)

			obs.obs_data_release(item)
			obs.obs_data_array_release(playlist)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end

		obs.remove_current_callback()
	end
end

-- The "Add replay" hotkey callback
function add_replay(pressed)
	if not pressed then
		return
	end

	set_current()

	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()
	if replay_buffer ~= nil then
		-- Call the procedure of the replay buffer named "get_last_replay" to
		-- get the last replay created by the replay buffer
		local ph = obs.obs_output_get_proc_handler(replay_buffer)
		obs.proc_handler_call(ph, "save", nil)

		-- Set a 1-second timer to attempt playback every 1 second
		-- until the replay is available
		if obs.obs_output_active(replay_buffer) then
			attempts = 0
			obs.timer_add(try_add, 100)
		else
			obs.script_log(obs.LOG_WARNING, "Tried to save an instant replay, but the replay buffer is not active!")
		end

		obs.obs_output_release(replay_buffer)
	else
		obs.script_log(obs.LOG_WARNING, "Tried to save an instant replay, but found no active replay buffer!")
	end
end

-- The "Clear playlist" hotkey callback
function clear_playlist(pressed)
	if not pressed then
		return
	end

	local source = obs.obs_get_source_by_name(vlc_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		local playlist = obs.obs_data_array_create()
		obs.obs_data_set_array(settings, "playlist", playlist)
--		obs.obs_data_set_bool(settings, "loop", false)
--		obs.obs_data_set_bool(settings, "shuffle", false)
		obs.obs_data_set_string(settings, "playback_behavior", stop_restart)
		obs.obs_source_update(source, settings)
		obs.obs_data_array_release(playlist)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

function frontend_event(e)
	if e == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
		local scene = obs.obs_frontend_get_current_scene()
		local name = obs.obs_source_get_name(scene)
		if name == scene_name then
			replaying = true
		elseif replaying and name ~= scene_name then
			clear_playlist(true)
			replaying = false
		end
	end
end

----------------------------------------------------------

-- A function named script_update will be called when settings are changed
function script_update(settings)
	source_name = obs.obs_data_get_string(settings, "source")
	vlc_name = obs.obs_data_get_string(settings, "vlc_source")
	scene_name = obs.obs_data_get_string(settings, "scene")
	autoclear = obs.obs_data_get_bool(settings, "autoclear")
	addall = obs.obs_data_get_bool(settings, "addall")
	replaylength = obs.obs_data_get_int(settings, "replaylength")
	if autoclear then
		obs.obs_frontend_add_event_callback(frontend_event)
	else
		obs.obs_frontend_remove_event_callback(frontend_event)
	end
	clear_playlist(true)
	clear_instant()
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Requires an active Replay Buffer for all functionality. When the \"Instant Replay\" hotkey is triggered, saves the replay from the Replay Buffer and plays it in the Replay Source when ready. When the \"Add Highlight\" hotkey is triggered, saves a Highlight from the Replay Buffer and adds it to the Highlights Source playlist. All accumulated Highlights can be played back by transitioning to the Highlights Scene. The Highlights playlist can be cleared with the \"Clear Highlights\" hotkey or automatically when leaving the Highlights Scene if selected.\n\nTweaked by Dave from the awesome Instant Replay by Dregu & Jim"
end

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	props = obs.obs_properties_create()

	local m = obs.obs_properties_add_list(props, "source", "Replay Source (Media)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local msources = obs.obs_enum_sources()
	if msources ~= nil then
		for _, source in ipairs(msources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "ffmpeg_source" then
				local mname = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(m, mname, mname)
			end
		end
	end

	obs.obs_properties_add_bool(props, "addall", "Add Replays to Highlights playlist")

	local v = obs.obs_properties_add_list(props, "vlc_source", "Highlights Source (VLC)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local vsources = obs.obs_enum_sources()
	if vsources ~= nil then
		for _, source in ipairs(vsources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "vlc_source" then
				local vname = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(v, vname, vname)
			end
		end
	end

	local s = obs.obs_properties_add_list(props, "scene", "Highlights Scene", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local scenes = obs.obs_frontend_get_scenes()
	if scenes ~= nil then
		for _, scene in ipairs(scenes) do
			local sname = obs.obs_source_get_name(scene)
			obs.obs_property_list_add_string(s, sname, sname)
		end
	end

	obs.obs_properties_add_bool(props, "autoclear", "Clear Highlights when leaving Scene")

	obs.obs_properties_add_int(props, "replaylength", "Replay length (seconds)", 20, 21600, 1)

	obs.source_list_release(scenes)
	obs.source_list_release(msources)
	obs.source_list_release(vsources)
	return props
end

-- A function named script_load will be called on startup
function script_load(settings)
	instant_hotkey_id = obs.obs_hotkey_register_frontend("instant_replay.trigger", "Instant Replay", instant_replay)
	local instant_hotkey_save_array = obs.obs_data_get_array(settings, "instant_replay.trigger")
	obs.obs_hotkey_load(instant_hotkey_id, instant_hotkey_save_array)
	obs.obs_data_array_release(instant_hotkey_save_array)

	add_hotkey_id = obs.obs_hotkey_register_frontend("add_replay.trigger", "Add Highlight to playlist", add_replay)
	local add_hotkey_save_array = obs.obs_data_get_array(settings, "add_replay.trigger")
	obs.obs_hotkey_load(add_hotkey_id, add_hotkey_save_array)
	obs.obs_data_array_release(add_hotkey_save_array)

	clear_hotkey_id = obs.obs_hotkey_register_frontend("clear_playlist.trigger", "Clear Highlight playlist", clear_playlist)
	local clear_hotkey_save_array = obs.obs_data_get_array(settings, "clear_playlist.trigger")
	obs.obs_hotkey_load(clear_hotkey_id, clear_hotkey_save_array)
	obs.obs_data_array_release(clear_hotkey_save_array)

	if autoclear then
		obs.obs_frontend_add_event_callback(frontend_event)
	end
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local instant_hotkey_save_array = obs.obs_hotkey_save(instant_hotkey_id)
	obs.obs_data_set_array(settings, "instant_replay.trigger", instant_hotkey_save_array)
	obs.obs_data_array_release(instant_hotkey_save_array)

	local add_hotkey_save_array = obs.obs_hotkey_save(add_hotkey_id)
	obs.obs_data_set_array(settings, "add_replay.trigger", add_hotkey_save_array)
	obs.obs_data_array_release(add_hotkey_save_array)

	local clear_hotkey_save_array = obs.obs_hotkey_save(clear_hotkey_id)
	obs.obs_data_set_array(settings, "clear_playlist.trigger", clear_hotkey_save_array)
	obs.obs_data_array_release(clear_hotkey_save_array)
end
