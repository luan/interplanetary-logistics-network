local State = require("__interplanetary-logistics-network__.state")
local Transfer = require("__interplanetary-logistics-network__.transfer")
local Settings = require("__interplanetary-logistics-network__.settings_util")

script.on_init(function()
  State.init()
  Settings.invalidate()
end)

script.on_configuration_changed(function()
  State.init()
  Settings.invalidate()
end)

script.on_event(defines.events.on_object_destroyed, function(event)
  if not storage.interplanetary_chests then return end
  for unit_number, chest_data in pairs(storage.interplanetary_chests) do
    if chest_data.entity and not chest_data.entity.valid then
      if chest_data.animation_entity and chest_data.animation_entity.valid then chest_data.animation_entity.destroy() end
      storage.transfer_cooldowns[unit_number] = nil
      storage.emission_timers[unit_number] = nil
      storage.power_failure_notifications[unit_number] = nil
      storage.power_failure_counts[unit_number] = nil
      storage.interplanetary_chests[unit_number] = nil
    end
  end
end)

script.on_event({ defines.events.on_built_entity, defines.events.on_robot_built_entity }, function(event)
  local e = event.entity
  if not e or not e.valid then return end
  if e.name == "interplanetary-roboport" or e.name == "interplanetary-provider-power-interface" or e.name == "interplanetary-requester-power-interface" then return end
  if e.name == "interplanetary-provider-chest" or e.name == "interplanetary-requester-chest" then Transfer.register_chest(e) end
end)

script.on_event({ defines.events.on_entity_died, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.script_raised_destroy }, function(event)
  local e = event.entity
  if not (e and e.valid and e.unit_number) then return end
  local data = storage.interplanetary_chests[e.unit_number]
  if not data then return end
  storage.emission_timers[e.unit_number] = nil
  storage.transfer_cooldowns[e.unit_number] = nil
  storage.power_failure_notifications[e.unit_number] = nil
  storage.power_failure_counts[e.unit_number] = nil
  if data.animation_entity and data.animation_entity.valid then data.animation_entity.destroy() end
  storage.interplanetary_chests[e.unit_number] = nil
end)

script.on_nth_tick(1, function() Transfer.on_fast_tick() end)
script.on_nth_tick(60, function() pcall(Transfer.on_slow_tick) end)

script.on_event(defines.events.script_raised_teleported, function(event)
  local e = event.entity
  if e and e.valid and (e.name == "interplanetary-provider-chest" or e.name == "interplanetary-requester-chest") then
    local d = storage.interplanetary_chests[e.unit_number]
    if d and d.animation_entity and d.animation_entity.valid then d.animation_entity.teleport(e.position) end
  end
end)

script.on_event(defines.events.on_entity_cloned, function(event)
  local s = event.source
  local d = event.destination
  if not (s and s.valid and d and d.valid) then return end
  if s.name ~= "interplanetary-provider-chest" and s.name ~= "interplanetary-requester-chest" then return end
  storage.interplanetary_chests[d.unit_number] = { entity = d, type = d.name }
  if storage.interplanetary_chests[s.unit_number] and storage.interplanetary_chests[s.unit_number].animation_entity then
    local a = storage.interplanetary_chests[s.unit_number].animation_entity
    if a.valid then a.destroy() end
  end
  storage.interplanetary_chests[s.unit_number] = nil
end)
