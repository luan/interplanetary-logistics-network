local State = require "__interplanetary-logistics-network__.state"
local Transfer = require "__interplanetary-logistics-network__.transfer"
local Settings = require "__interplanetary-logistics-network__.settings_util"

local function rebuild()
  State.init()
  Settings.invalidate()
  Transfer.rebuild()
end

script.on_init(rebuild)
script.on_configuration_changed(rebuild)

script.on_event(defines.events.on_object_destroyed, function(event)
  local unit = storage.destroyed_chests[event.registration_number]
  if unit then
    Transfer.remove_chest(unit)
  end
end)

script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, function(event)
  Transfer.register_chest(event.entity, event.tags and event.tags.iln)
end)

script.on_event({
  defines.events.on_entity_died,
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_space_platform_mined_entity,
  defines.events.script_raised_destroy,
}, function(event)
  local entity = event.entity
  if entity and entity.valid and entity.unit_number then
    Transfer.remove_chest(entity.unit_number)
  end
end)

script.on_event({ defines.events.on_pre_surface_deleted, defines.events.on_pre_surface_cleared }, function(event)
  for unit, chest in pairs(storage.interplanetary_chests) do
    if not chest.entity.valid or chest.entity.surface.index == event.surface_index then
      Transfer.remove_chest(unit)
    end
  end
end)

script.on_nth_tick(1, Transfer.on_fast_tick)
script.on_nth_tick(15, Transfer.on_slow_tick)

script.on_event(defines.events.script_raised_teleported, function(event)
  Transfer.refresh_chest(event.entity)
end)
script.on_event(defines.events.on_entity_cloned, function(event)
  local destination = event.destination
  if
    destination.name:find "^interplanetary%-"
    and (destination.type == "simple-entity-with-force" or destination.type == "electric-energy-interface")
  then
    -- Area cloning also clones helpers; each cloned chest creates its own helpers.
    destination.destroy()
    return
  end
  local source = storage.interplanetary_chests[event.source.unit_number]
  Transfer.register_chest(destination, source)
end)
script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local source = storage.interplanetary_chests[event.source.unit_number]
  local destination = storage.interplanetary_chests[event.destination.unit_number]
  if source and destination and event.source.name == event.destination.name then
    Transfer.cancel_transfers(event.destination.unit_number)
    Transfer.register_chest(event.destination, source)
  end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local blueprint = event.record or event.stack
  if not blueprint then
    return
  end
  for index, entity in pairs(event.mapping.get()) do
    local chest = storage.interplanetary_chests[entity.unit_number]
    if chest then
      -- Unit numbers do not survive blueprint export; preserve the source surface only.
      blueprint.set_blueprint_entity_tag(index, "iln", {
        source_surface = chest.source_surface,
        allow_local = chest.allow_local,
        enabled = chest.enabled,
      })
    end
  end
end)
