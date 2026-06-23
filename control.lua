local debug_hec = false

local controllers = {
  [defines.controllers.ghost]     = "ghost",     --[0]
  [defines.controllers.character] = "character", --[1]
  [defines.controllers.god]       = "god",       --[2]
--[3]                             = nil,         --[3] currently nil, is pause in Factorio's source code https://discord.com/channels/139677590393716737/306402592265732098/1505828859201847396
  [defines.controllers.editor]    = "editor",
  [defines.controllers.spectator] = "spectator",
  [defines.controllers.cutscene]  = "cutscene",
  [defines.controllers.remote]    = "remote"
}

--- @params event ConfigurationChangedData or nil
local rebuild_surfaces = function(event)
  if not (storage and game) then
    error("storage or game global objects are unavailable")
  end
  -- (Re)build table of all surfaces and reset their clouds
  storage.surfaces = {}
  local surfaces = storage.surfaces
  for _, surface in pairs(game.surfaces) do
    surfaces[surface.index] = {editor_count = 0}
    surface.show_clouds = true
  end
  -- Set editor_count and hide clouds on surfaces with editors
  local editor_controller = defines.controllers.editor
  for _, player in pairs(game.connected_players) do
    if player.physical_controller_type  == editor_controller then
      surfaces[player.surface.index].editor_count = surfaces[player.surface.index].editor_count + 1
      player.surface.show_clouds = false
    end
  end
end

--- Prints an event's player controller info, then prints storage.surfaces table
--- @param event An event that contains player_index (usually on_player_* events)
local print_hec_player_event = function(event)
  local event_names = {
    [defines.events.on_pre_player_toggled_map_editor] = "on_pre_player_toggled_map_editor",
    [defines.events.on_player_changed_surface]        = "on_player_changed_surface",
    [defines.events.on_player_joined_game]            = "on_player_joined_game",
    [defines.events.on_player_left_game]              = "on_player_left_game"
  }
  local heading = nil
  if event_names[event.name] ~= nil then
    heading = "event: "..event_names[event.name]
  else
    heading = "event: "..event.name
  end
  if event.player_index then
    local player = game.get_player(event.player_index)
    heading = heading.."  surface: "..player.surface.name
                     .."  controller: "..controllers[player.controller_type]
                     .."  physical_controller: "..controllers[player.physical_controller_type]
  end
  game.print(heading)
  if not storage.surfaces then
    error("storage.surfaces is nil")
  else
    for k, surface in pairs(storage.surfaces) do
      game.print(k.." editor_count = "..surface.editor_count)
    end
  end
end

script.on_init(rebuild_surfaces)

script.on_configuration_changed(rebuild_surfaces)

script.on_event({
    defines.events.on_pre_player_toggled_map_editor,
    defines.events.on_player_changed_surface,
    defines.events.on_player_joined_game,
    defines.events.on_player_left_game
  }, function(event)
    local player = game.get_player(event.player_index)
    local is_editor = player.physical_controller_type  == defines.controllers.editor
    -- Early return if non-editor changed surfaces or joined or left (the most frequent events).
    if not is_editor and event.name ~= defines.events.on_pre_player_toggled_map_editor then
      if debug_hec then print_hec_player_event(event) end
      return
    end
    local index = player.surface.index
    local surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then
      error(player.surface.name.." in storage is nil")
    end
    -- Editor will soon be disabled or editor left game
    if is_editor and (   event.name == defines.events.on_pre_player_toggled_map_editor
                      or event.name == defines.events.on_player_left_game) then
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then
        error("Event "..event.name..": "..player.surface.name..": editor_count is negative")
      end
    else -- Editor will soon be enabled, or editor joined game, or editor changed to this surface
      surface.editor_count = surface.editor_count + 1
    end
    game.surfaces[index].show_clouds = surface.editor_count == 0
    -- If editor changed surfaces, remove them from the previous surface
    if event.name == defines.events.on_player_changed_surface then
      index = event.surface_index -- Previous surface. Can be nil, which is not an error
      if not index then return end
      surface = storage.surfaces[index]
      if not (surface and surface.editor_count) then
        error(player.surface.name.." in storage is nil")
      end
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then
        error("Event "..event.name..": "..player.surface.name..": editor_count is negative")
      end
      game.surfaces[index].show_clouds = surface.editor_count == 0
    end
    if debug_hec then print_hec_player_event(event) end
  end)

script.on_event({
    defines.events.on_surface_created,
    defines.events.on_surface_imported
  }, function(event) storage.surfaces[event.surface_index] = {editor_count = 0} end)

script.on_event(defines.events.on_surface_deleted, function(event)
    storage.surfaces[event.surface_index] = nil end)
