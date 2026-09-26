local Settings = require "__interplanetary-logistics-network__.settings_util"
local State = require "__interplanetary-logistics-network__.state"

local M = {}
local efficiency = { normal = 1, uncommon = 0.85, rare = 0.7, epic = 0.5, legendary = 0.3 }
local speed = { normal = 1, uncommon = 0.9, rare = 0.75, epic = 0.6, legendary = 0.4 }

local function item_key(item)
  return item.name .. "/" .. item.quality
end

local function destroy(entity)
  if entity and entity.valid then
    entity.destroy()
  end
end

local function set_animation(chest)
  if not chest.entity.valid then
    return
  end
  local kind = chest.entity.name == "interplanetary-provider-chest" and "provider" or "requester"
  local name = "interplanetary-" .. kind .. "-animation-" .. ((chest.active_count or 0) > 0 and "active" or "idle")
  if chest.animation_entity and chest.animation_entity.valid and chest.animation_entity.name == name then
    return
  end
  destroy(chest.animation_entity)
  chest.animation_entity = chest.entity.surface.create_entity {
    name = name,
    position = chest.entity.position,
    force = chest.entity.force,
  }
  if chest.animation_entity then
    chest.animation_entity.destructible = false
  end
end

local function configure_logistics(chest)
  if chest.entity.name ~= "interplanetary-requester-chest" then
    return
  end
  local point = chest.entity.get_logistic_point(defines.logistic_member_index.logistic_container)
  if point then
    point.enabled = chest.allow_local == true
  end
end

function M.register_chest(entity, options)
  if not entity or not entity.valid then
    return
  end
  if entity.name ~= "interplanetary-provider-chest" and entity.name ~= "interplanetary-requester-chest" then
    return
  end
  local chest = storage.interplanetary_chests[entity.unit_number]
  if not chest then
    chest = { entity = entity, active_count = 0 }
    storage.interplanetary_chests[entity.unit_number] = chest
    chest.registration = script.register_on_object_destroyed(entity)
    storage.destroyed_chests[chest.registration] = entity.unit_number
  end
  if options then
    chest.source_surface = options.source_surface
    chest.source_provider = options.source_provider
    chest.allow_local = options.allow_local == true
    chest.enabled = options.enabled ~= false
  end
  configure_logistics(chest)
  set_animation(chest)
  return chest
end

local function finish_transfer(id)
  local transfer = storage.pending_transfers[id]
  if not transfer then
    return
  end
  destroy(transfer.provider_interface)
  destroy(transfer.buffer_interface)
  local reservations = storage.item_reservations[transfer.provider_id]
  if reservations then
    reservations[transfer.key] = (reservations[transfer.key] or 0) - transfer.count
    if reservations[transfer.key] <= 0 then
      reservations[transfer.key] = nil
    end
    if not next(reservations) then
      storage.item_reservations[transfer.provider_id] = nil
    end
  end
  for _, unit in ipairs { transfer.provider_id, transfer.buffer_id } do
    local chest = storage.interplanetary_chests[unit]
    if chest then
      chest.active_count = math.max(0, (chest.active_count or 0) - 1)
      if chest.entity.valid then
        chest.entity.custom_status = nil
        set_animation(chest)
      end
    end
  end
  storage.pending_transfers[id] = nil
end

function M.cancel_transfers(unit)
  for id, transfer in pairs(storage.pending_transfers) do
    if transfer.provider_id == unit or transfer.buffer_id == unit then
      finish_transfer(id)
    end
  end
end

function M.remove_chest(unit)
  M.cancel_transfers(unit)
  local chest = storage.interplanetary_chests[unit]
  if not chest then
    return
  end
  destroy(chest.animation_entity)
  if chest.registration then
    storage.destroyed_chests[chest.registration] = nil
  end
  storage.interplanetary_chests[unit] = nil
end

function M.refresh_chest(entity)
  local chest = storage.interplanetary_chests[entity.unit_number]
  if not chest then
    return M.register_chest(entity)
  end
  M.cancel_transfers(entity.unit_number)
  destroy(chest.animation_entity)
  configure_logistics(chest)
  set_animation(chest)
end

function M.rebuild()
  State.init()
  -- Pending jobs have not removed items. Cancel old jobs and rebuild all helper references.
  for _, transfer in pairs(storage.pending_transfers) do
    destroy(transfer.provider_interface)
    destroy(transfer.buffer_interface)
  end
  storage.pending_transfers = {}
  storage.item_reservations = {}
  storage.destroyed_chests = {}
  local previous = storage.interplanetary_chests
  storage.interplanetary_chests = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in
      pairs(surface.find_entities_filtered {
        name = {
          "interplanetary-provider-animation-idle",
          "interplanetary-provider-animation-active",
          "interplanetary-requester-animation-idle",
          "interplanetary-requester-animation-active",
          "interplanetary-provider-power-interface",
          "interplanetary-requester-power-interface",
          "interplanetary-roboport",
        },
      })
    do
      entity.destroy()
    end
    for _, entity in
      pairs(surface.find_entities_filtered {
        name = { "interplanetary-provider-chest", "interplanetary-requester-chest" },
      })
    do
      M.register_chest(entity, previous[entity.unit_number])
    end
  end
  for _, name in ipairs {
    "active_emissions",
    "emission_timers",
    "active_transfers",
    "transfer_cooldowns",
    "power_failure_notifications",
    "power_failure_counts",
    "reservations_by_transfer",
  } do
    storage[name] = nil
  end
end

local function requests(entity)
  local result = {}
  local sections = entity.get_logistic_sections()
  if not sections then
    return result
  end
  for _, section in pairs(sections.sections) do
    if section.active and section.multiplier > 0 then
      for _, filter in pairs(section.filters) do
        local value = filter.value
        if value and (value.type == nil or value.type == "item") and (filter.min or 0) > 0 then
          local item = { name = value.name, quality = value.quality or "normal" }
          local key = item_key(item)
          local request = result[key] or { item = item, count = 0 }
          request.count = request.count + math.floor(filter.min * section.multiplier)
          result[key] = request
        end
      end
    end
  end
  return result
end

local function route_matches(provider, requester, chest)
  return provider.valid
    and requester.valid
    and provider.force == requester.force
    and provider.surface ~= requester.surface
    and (not chest.source_surface or provider.surface.name == chest.source_surface)
    and (not chest.source_provider or provider.unit_number == chest.source_provider)
end

local function is_enabled(chest)
  if chest.enabled == false then
    return false
  end
  -- The general entity status can be "out of logistic network" even when the circuit is false.
  local behavior = chest.entity.get_control_behavior()
  return not behavior or not behavior.circuit_condition_enabled or behavior.circuit_condition.fulfilled == true
end

local function request_need(transfer)
  local chest = storage.interplanetary_chests[transfer.buffer_id]
  if not chest or not is_enabled(chest) or not route_matches(transfer.provider, transfer.buffer, chest) then
    return 0
  end
  local request = requests(transfer.buffer)[transfer.key]
  return request and math.max(0, request.count - transfer.buffer.get_item_count(transfer.item)) or 0
end

local function research_speed(force)
  local multiplier = 1
  for i = 1, 4 do
    local technology = force.technologies["interplanetary-logistics-speed-" .. i]
    if technology and technology.researched then
      multiplier = multiplier * (i == 4 and 0.8 or 0.85)
    end
  end
  return multiplier
end

local function create_interface(entity, kind, per_tick)
  local interface = entity.surface.create_entity {
    name = "interplanetary-" .. kind .. "-power-interface",
    position = entity.position,
    force = entity.force,
    quality = entity.quality,
  }
  if interface then
    interface.destructible = false
    interface.electric_buffer_size = per_tick
  end
  return interface
end

local function begin_transfer(provider, requester, item, count)
  local config = Settings.get()
  local provider_quality, requester_quality = provider.quality.name, requester.quality.name
  local duration = math.max(
    1,
    math.ceil(
      config.transfer_duration
        * math.max(speed[provider_quality] or 1, speed[requester_quality] or 1)
        * research_speed(requester.force)
    )
  )
  local stacks = count / prototypes.item[item.name].stack_size
  local sending = config.sending_energy * stacks * (efficiency[provider_quality] or 1)
  local receiving = config.receiving_energy * stacks * (efficiency[requester_quality] or 1)
  local pi = sending > 0 and create_interface(provider, "provider", sending / duration) or nil
  local bi = receiving > 0 and create_interface(requester, "requester", receiving / duration) or nil
  if (sending > 0 and not pi) or (receiving > 0 and not bi) then
    destroy(pi)
    destroy(bi)
    return
  end
  storage.next_transfer_id = storage.next_transfer_id + 1
  local key = item_key(item)
  storage.pending_transfers[storage.next_transfer_id] = {
    provider = provider,
    buffer = requester,
    provider_id = provider.unit_number,
    buffer_id = requester.unit_number,
    item = item,
    key = key,
    count = count,
    provider_interface = pi,
    buffer_interface = bi,
    sending_remaining = sending,
    receiving_remaining = receiving,
    sending_per_tick = sending / duration,
    receiving_per_tick = receiving / duration,
    created_tick = game.tick,
    duration = duration,
  }
  local reservations = storage.item_reservations[provider.unit_number] or {}
  storage.item_reservations[provider.unit_number] = reservations
  reservations[key] = (reservations[key] or 0) + count
  for _, entity in ipairs { provider, requester } do
    local chest = storage.interplanetary_chests[entity.unit_number]
    chest.active_count = (chest.active_count or 0) + 1
    set_animation(chest)
  end
end

local function drain(interface, remaining, per_tick)
  if remaining <= 0 then
    return 0
  end
  if not interface or not interface.valid then
    return remaining
  end
  local amount = math.min(interface.energy, remaining, per_tick)
  interface.energy = interface.energy - amount
  remaining = math.max(0, remaining - amount)
  if remaining == 0 then
    interface.destroy()
  else
    -- Only charge energy that this job can consume; never discard a full buffer on completion.
    interface.electric_buffer_size = math.min(remaining, per_tick)
  end
  return remaining
end

local function move_items(provider, requester, item, count)
  local source = provider.get_inventory(defines.inventory.chest)
  local target = requester.get_inventory(defines.inventory.chest)
  local limit = target.supports_bar() and target.get_bar() - 1 or #target
  local remaining = count
  -- Transfer actual stacks so quality, spoilage, equipment, tags and blueprints survive.
  for i = 1, #source do
    local stack = source[i]
    if stack.valid_for_read and stack.name == item.name and stack.quality.name == item.quality then
      for j = 1, limit do
        if not stack.valid_for_read or remaining == 0 then
          break
        end
        local before = stack.count
        target[j].transfer_stack(stack, math.min(remaining, before))
        remaining = remaining - (before - (stack.valid_for_read and stack.count or 0))
      end
    end
    if remaining == 0 then
      break
    end
  end
  return count - remaining
end

function M.on_fast_tick()
  for id, transfer in pairs(storage.pending_transfers) do
    local provider, requester = transfer.provider, transfer.buffer
    if
      not provider.valid
      or not requester.valid
      or request_need(transfer) < transfer.count
      or provider.get_item_count(transfer.item) < transfer.count
    then
      finish_transfer(id)
    elseif
      (transfer.sending_remaining > 0 and not (transfer.provider_interface and transfer.provider_interface.valid))
      or (transfer.receiving_remaining > 0 and not (transfer.buffer_interface and transfer.buffer_interface.valid))
    then
      finish_transfer(id)
    else
      transfer.sending_remaining =
        drain(transfer.provider_interface, transfer.sending_remaining, transfer.sending_per_tick)
      transfer.receiving_remaining =
        drain(transfer.buffer_interface, transfer.receiving_remaining, transfer.receiving_per_tick)
      if game.tick - transfer.created_tick >= transfer.duration then
        if transfer.sending_remaining < 0.001 and transfer.receiving_remaining < 0.001 then
          move_items(provider, requester, transfer.item, transfer.count)
          finish_transfer(id)
        else
          for _, entity in ipairs { provider, requester } do
            entity.custom_status =
              { diode = defines.entity_status_diode.yellow, label = { "iln-status.waiting-for-power" } }
          end
        end
      end
    end
  end
end

function M.on_slow_tick()
  local providers, requesters = {}, {}
  for unit, chest in pairs(storage.interplanetary_chests) do
    if not chest.entity.valid then
      M.remove_chest(unit)
    elseif chest.entity.name == "interplanetary-provider-chest" then
      providers[#providers + 1] = chest.entity
    else
      configure_logistics(chest)
      requesters[#requesters + 1] = chest
    end
  end
  table.sort(providers, function(a, b)
    return a.unit_number < b.unit_number
  end)
  for _, chest in ipairs(requesters) do
    local requester = chest.entity
    if is_enabled(chest) then
      local pending = {}
      for _, transfer in pairs(storage.pending_transfers) do
        if transfer.buffer_id == requester.unit_number then
          pending[transfer.key] = true
        end
      end
      for key, request in pairs(requests(requester)) do
        local need = request.count - requester.get_item_count(request.item)
        if need > 0 and not pending[key] then
          local capacity = requester.get_inventory(defines.inventory.chest).get_insertable_count(request.item)
          for _, provider in ipairs(providers) do
            if route_matches(provider, requester, chest) then
              local reserved = storage.item_reservations[provider.unit_number]
              local available = provider.get_item_count(request.item) - (reserved and reserved[key] or 0)
              local count = math.min(
                need,
                available,
                capacity,
                prototypes.item[request.item.name].stack_size * Settings.get().stacks_per_transfer
              )
              if count > 0 then
                begin_transfer(provider, requester, request.item, count)
                break
              end
            end
          end
        end
      end
    end
  end
end

return M
