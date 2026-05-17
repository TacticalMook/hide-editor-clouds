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
    if player.controller_type == editor_controller then
      surfaces[player.surface.index].editor_count = surfaces[player.surface.index].editor_count + 1
      surface.show_clouds = false
    end
  end
end

--- Print function for crude debugging
local print_surfaces = function()
  if not storage.surfaces then game.print("storage.surfaces is nil")
  else for k, surface in pairs(storage.surfaces) do game.print(k.." editor_count = "..surface.editor_count) end end
  game.print("---")
end

script.on_init(rebuild_surfaces)

script.on_configuration_changed(rebuild_surfaces)

script.on_event({
    defines.events.on_player_toggled_map_editor,
    defines.events.on_player_changed_surface,
    defines.events.on_player_joined_game,
    defines.events.on_player_left_game
  }, function(event)
    local player = game.get_player(event.player_index)
    -- Early return if non-editor changed surfaces or joined or left (the most frequent events).
    local is_editor = player.controller_type == defines.controllers.editor
    if not is_editor and event.name ~= defines.events.on_player_toggled_map_editor then return end
    local index = player.surface.index
    local surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then error(player.surface.name.." in storage is nil") return end
    -- Editor joined game, editor changed to this surface, or player enabled editor
    if is_editor and event.name ~= defines.events.on_player_left_game then
      surface.editor_count = surface.editor_count + 1
    else -- Editor left game or player disabled editor
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then error(player.surface.name.." editor_count is negative") end
    end
    game.surfaces[index].show_clouds = surface.editor_count == 0
    -- If on_player_changed_surface, remove editor from the previous surface
    if event.name == defines.events.on_player_changed_surface then
      index = event.surface_index -- Previous surface. Can be nil, which is not an error
      if not index then return end
      surface = storage.surfaces[index]
      if not (surface and surface.editor_count) then error(player.surface.name.." in storage is nil") return end
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then error(player.surface.name.." editor_count is negative") end
      game.surfaces[index].show_clouds = surface.editor_count == 0
    end
  end)

script.on_event({
    defines.events.on_surface_created,
    defines.events.on_surface_imported
  }, function(event) storage.surfaces[event.surface_index] = {editor_count = 0} end)

script.on_event(defines.events.on_surface_deleted, function(event)
    storage.surfaces[event.surface_index] = nil end)

--[==[Separate event handlers. Does not have parity with the combined event handler
script.on_event(defines.events.on_player_toggled_map_editor,
  function(event)
    local player = game.get_player(event.player_index)
    local index = player.surface.index
    local surface = storage.surfaces[index] or nil
    if not (surface and surface.editor_count) then error(player.surface.name.." in storage is nil") return end
    if player.controller_type == defines.controllers.editor then
      surface.editor_count = surface.editor_count + 1
    else
      surface.editor_count = surface.editor_count - 1
      if surface.editor_count < 0 then error(player.surface.name.." editor_count is negative") end
    end
    game.surfaces[index].show_clouds = surface.editor_count == 0
  end)

script.on_event(defines.events.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index)
    if player.controller_type ~= defines.controllers.editor then return end
    -- Handle surface the editor joined
    local index = player.surface.index
    local surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then error(player.surface.name.." in storage is nil") return end
    surface.editor_count = surface.editor_count + 1
    game.surfaces[index].show_clouds = surface.editor_count == 0
    -- Handle surface the editor left
    -- Can be nil, which is not an error
    index = event.surface_index
    if not index then return end
    surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then error(player.surface.name .. " is nil") return end
    surface.editor_count = surface.editor_count - 1
    game.surfaces[index].show_clouds = surface.editor_count == 0
    if surface.editor_count < 0 then error(player.surface.name.." editor_count is negative") end
  end)

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if player.controller_type ~= defines.controllers.editor then return end
    local index = player.surface.index
    local surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then error(player.surface.name .. " is nil") return end
    local count = surface.editor_count
    count = count + 1
    game.surfaces[index].show_clouds = count == 0
    -- if count < 0 then error(player.surface.name .. " editor_count is negative") end
  end)

script.on_event(defines.events.on_player_left_game, function(event)
    local player = game.get_player(event.player_index)
    if player.controller_type ~= defines.controllers.editor then return end
    local index = player.surface.index
    local surface = storage.surfaces[index]
    if not (surface and surface.editor_count) then error(player.surface.name .. " is nil") return end
    local count = surface.editor_count
    count = count - 1
    game.surfaces[index].show_clouds = count == 0
    if count < 0 then error(player.surface.name .. " editor_count is negative") end
  end)
]==]