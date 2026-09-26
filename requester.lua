local Transfer = require "__interplanetary-logistics-network__.transfer"
local M = {}

local function surface_name(surface)
  return surface.platform and surface.platform.name
    or surface.localised_name
    or (surface.planet and surface.planet.localised_name)
    or surface.name
end

function M.close(player)
  local frame = player.gui.relative.iln_requester
  if frame then
    frame.destroy()
  end
end

function M.open(player, entity)
  M.close(player)
  if not entity or not entity.valid or entity.name ~= "interplanetary-requester-chest" then
    return
  end
  local chest = storage.interplanetary_chests[entity.unit_number]
  if not chest then
    return
  end
  local frame = player.gui.relative.add {
    type = "frame",
    name = "iln_requester",
    caption = { "iln-gui.title" },
    direction = "vertical",
    anchor = { gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right },
    tags = { unit = entity.unit_number },
  }
  frame.add { type = "checkbox", name = "iln_enabled", caption = { "iln-gui.enabled" }, state = chest.enabled ~= false }
  frame.add {
    type = "checkbox",
    name = "iln_local",
    caption = { "iln-gui.allow-local" },
    tooltip = { "iln-gui.allow-local-tooltip" },
    state = chest.allow_local == true,
  }
  frame.add { type = "label", caption = { "iln-gui.source-surface" } }
  local surfaces, names, index = { "" }, { { "iln-gui.any-surface" } }, 1
  local sorted = {}
  for _, surface in pairs(game.surfaces) do
    if surface ~= entity.surface then
      sorted[#sorted + 1] = surface.name
    end
  end
  table.sort(sorted)
  for _, name in ipairs(sorted) do
    surfaces[#surfaces + 1] = name
    local surface = game.surfaces[name]
    names[#names + 1] = surface_name(surface)
    if name == chest.source_surface then
      index = #names
    end
  end
  -- Keep missing routes visible; a deleted source must never silently become "any".
  if chest.source_surface and index == 1 then
    surfaces[#surfaces + 1] = chest.source_surface
    names[#names + 1] = { "iln-gui.missing-surface", chest.source_surface }
    index = #names
  end
  frame.add {
    type = "drop-down",
    name = "iln_surface",
    items = names,
    selected_index = index,
    tags = { surfaces = surfaces },
  }
  frame.add { type = "label", caption = { "iln-gui.source-provider" } }
  local providers, labels, selected = { 0 }, { { "iln-gui.any-provider" } }, 1
  local candidates = {}
  for unit, data in pairs(storage.interplanetary_chests) do
    local provider = data.entity
    if
      provider.valid
      and provider.name == "interplanetary-provider-chest"
      and provider.force == entity.force
      and provider.surface ~= entity.surface
      and (not chest.source_surface or provider.surface.name == chest.source_surface)
    then
      candidates[#candidates + 1] = unit
    end
  end
  table.sort(candidates)
  for _, unit in ipairs(candidates) do
    local provider = storage.interplanetary_chests[unit].entity
    providers[#providers + 1] = unit
    labels[#labels + 1] = {
      "iln-gui.provider-location",
      surface_name(provider.surface),
      math.floor(provider.position.x),
      math.floor(provider.position.y),
      unit,
    }
    if unit == chest.source_provider then
      selected = #labels
    end
  end
  if chest.source_provider and selected == 1 then
    providers[#providers + 1] = chest.source_provider
    labels[#labels + 1] = { "iln-gui.missing-provider", chest.source_provider }
    selected = #labels
  end
  frame.add {
    type = "drop-down",
    name = "iln_provider",
    items = labels,
    selected_index = selected,
    tags = { providers = providers },
  }
end

function M.changed(event)
  local element = event.element
  if not element or not element.valid or not element.parent or element.parent.name ~= "iln_requester" then
    return
  end
  local player = game.get_player(event.player_index)
  local chest = storage.interplanetary_chests[element.parent.tags.unit]
  if not chest or not chest.entity.valid or chest.entity.force ~= player.force then
    M.close(player)
    return
  end
  if element.name == "iln_enabled" then
    chest.enabled = element.state
  elseif element.name == "iln_local" then
    chest.allow_local = element.state
  elseif element.name == "iln_surface" then
    local name = element.tags.surfaces[element.selected_index]
    chest.source_surface = name ~= "" and name or nil
    chest.source_provider = nil
  elseif element.name == "iln_provider" then
    local unit = element.tags.providers[element.selected_index]
    chest.source_provider = unit ~= 0 and unit or nil
  else
    return
  end
  Transfer.refresh_chest(chest.entity)
  M.open(player, chest.entity)
end

return M
