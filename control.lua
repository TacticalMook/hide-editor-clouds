local debug_hec = false

local controllers = {
  [defines.controllers.ghost]     = "ghost",     --[0]
  [defines.controllers.character] = "character", --[1]
  [defines.controllers.god]       = "god",       --[2]
--[3]                             = nil,         --[3]
  [defines.controllers.editor]    = "editor",
  [defines.controllers.spectator] = "spectator",
  [defines.controllers.cutscene]  = "cutscene",
  [defines.controllers.remote]    = "remote"
}

--- @params event ConfigurationChangedData or nil
local rebuild_surfaces = function(event)
  if not (storage and game) then error("storage or game global objects are unavailable") return end
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

--- Print storage.surfaces table
--- @param? title A value (usually string) to print as a title
local print_surfaces = function(title)
  if debug_hec then
    if not storage.surfaces then game.print("storage.surfaces is nil")
    if title then game.print(title) end
    else for k, surface in pairs(storage.surfaces) do game.print(k.." editor_count = "..surface.editor_count) end end
  end
end

--- Print a player's controllers from a player event
--- @param event An event that contains player_index (usually on_player_XX events)
local print_player_controller = function(event)
  if debug_hec then
    local player = game.get_player(event.player_index)
    game.print(player.surface.name.."; "
      .."   controller: "..controllers[player.controller_type]
      .."   physical_controller: "..controllers[player.physical_controller_type])
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
    if not is_editor and event.name ~= defines.events.on_pre_player_toggled_map_editor then print_surfaces("early return") return end
    local index = player.surface.index
    local surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then error(player.surface.name.." in storage is nil") return end
    -- Editor will soon be disabled or editor left game
    if is_editor and (   event.name == defines.events.on_pre_player_toggled_map_editor
                      or event.name == defines.events.on_player_left_game) then
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then error("Event "..event.name..": "..player.surface.name..": editor_count is negative") end
    else -- Editor will soon be enabled, or editor joined game, or editor changed to this surface
      surface.editor_count = surface.editor_count + 1
    end
    game.surfaces[index].show_clouds = surface.editor_count == 0
    -- If editor changed surfaces, remove them from the previous surface
    if event.name == defines.events.on_player_changed_surface then
      index = event.surface_index -- Previous surface. Can be nil, which is not an error
      if not index then return end
      surface = storage.surfaces[index]
      if not (surface and surface.editor_count) then error(player.surface.name.." in storage is nil") return end
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then error("Event "..event.name..": "..player.surface.name..": editor_count is negative") end
      game.surfaces[index].show_clouds = surface.editor_count == 0
    end
    print_surfaces("return")
  end)

script.on_event({
    defines.events.on_surface_created,
    defines.events.on_surface_imported
  }, function(event) storage.surfaces[event.surface_index] = {editor_count = 0} end)

script.on_event(defines.events.on_surface_deleted, function(event)
    storage.surfaces[event.surface_index] = nil end)

--[[
script.on_event({
    defines.events.on_player_toggled_map_editor,
    defines.events.on_player_changed_surface
  }, function(event) print_player_controller(event) end)
]]