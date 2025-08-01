-- Control stage for Interplanetary Logistics Network
-- Runtime logic for interplanetary logistics chests

-- Initialize storage variables
local function init_storage()
  storage.interplanetary_chests = storage.interplanetary_chests or {}
  storage.transfer_cooldowns = storage.transfer_cooldowns or {}
  storage.pending_transfers = storage.pending_transfers or {}
  storage.active_emissions = storage.active_emissions or {}
  storage.emission_timers = storage.emission_timers or {}
  storage.active_transfers = storage.active_transfers or {}
end

-- Initialize on first run
script.on_init(function()
  init_storage()
end)

-- Configuration changed (mod updates, settings changes)
script.on_configuration_changed(function()
  init_storage()
end)

-- Handle entity destruction callbacks
script.on_event(defines.events.on_object_destroyed, function(event)
  if storage.interplanetary_chests and event.registration_number then
    for unit_number, chest_data in pairs(storage.interplanetary_chests) do
      if chest_data.entity and not chest_data.entity.valid then
        -- Container was destroyed, clean up animation entity
        if chest_data.animation_entity and chest_data.animation_entity.valid then
          chest_data.animation_entity.destroy()
        end

        -- Clean up all related data
        storage.transfer_cooldowns[unit_number] = nil
        storage.emission_timers[unit_number] = nil
        storage.interplanetary_chests[unit_number] = nil
      end
    end
  end
end)

-- Power consumption settings with speed scaling
local function get_power_settings()
  local speed_setting = settings.startup["interplanetary-transfer-speed"].value
  local power_setting = settings.startup["interplanetary-power-cost"].value

  local speed_configs = {
    ["ultra-slow"] = {duration = 16 * 60, power_multiplier = 0.625}, -- 16s, 62.5% power
    ["slow"] = {duration = 8 * 60, power_multiplier = 0.75},         -- 8s, 75% power
    ["normal"] = {duration = 4 * 60, power_multiplier = 1.0},        -- 4s, 100% power
    ["fast"] = {duration = 2 * 60, power_multiplier = 2.0},          -- 2s, 200% power
    ["ultra-fast"] = {duration = 1 * 60, power_multiplier = 5.0}     -- 1s, 500% power
  }

  local power_configs = {
    ["free"] = {sending = 0, receiving = 0},           -- 0MW / 0MW
    ["cheap"] = {sending = 4000, receiving = 1000},    -- 4MW / 1MW
    ["normal"] = {sending = 16000, receiving = 4000},  -- 16MW / 4MW (default)
    ["expensive"] = {sending = 40000, receiving = 10000}, -- 40MW / 10MW
    ["extreme"] = {sending = 80000, receiving = 20000}    -- 80MW / 20MW
  }

  local speed_config = speed_configs[speed_setting] or speed_configs["normal"]
  local power_config = power_configs[power_setting] or power_configs["normal"]

  return {
    receiving_power = power_config.receiving * 1000 * speed_config.power_multiplier,
    sending_power = power_config.sending * 1000 * speed_config.power_multiplier,
    transfer_duration = speed_config.duration
  }
end

-- Quality-based efficiency bonuses (more progressive)
local function get_quality_efficiency(entity)
  if not entity or not entity.valid then return 1.0 end

  local quality_name = entity.quality and entity.quality.name or "normal"
  local quality_efficiency = {
    ["normal"] = 1.0,
    ["uncommon"] = 0.85,  -- 15% more efficient
    ["rare"] = 0.7,       -- 30% more efficient
    ["epic"] = 0.5,       -- 50% more efficient
    ["legendary"] = 0.3   -- 70% more efficient
  }

  return quality_efficiency[quality_name] or 1.0
end

-- Quality-based speed bonuses (more progressive)
local function get_quality_speed_bonus(entity)
  if not entity or not entity.valid then return 1.0 end

  local quality_name = entity.quality and entity.quality.name or "normal"
  local quality_speed_bonus = {
    ["normal"] = 1.0,
    ["uncommon"] = 0.9,   -- 10% faster
    ["rare"] = 0.75,      -- 25% faster
    ["epic"] = 0.6,       -- 40% faster
    ["legendary"] = 0.4   -- 60% faster
  }

  return quality_speed_bonus[quality_name] or 1.0
end

-- Research-based speed bonuses
local function get_research_speed_bonus(force)
  if not force or not force.valid then return 1.0 end

  local speed_bonus = 1.0
  if force.technologies["interplanetary-logistics-speed-1"] and force.technologies["interplanetary-logistics-speed-1"].researched then
    speed_bonus = speed_bonus * 0.85  -- 15% faster
  end
  if force.technologies["interplanetary-logistics-speed-2"] and force.technologies["interplanetary-logistics-speed-2"].researched then
    speed_bonus = speed_bonus * 0.85  -- Additional 15% faster (27.75% total)
  end
  if force.technologies["interplanetary-logistics-speed-3"] and force.technologies["interplanetary-logistics-speed-3"].researched then
    speed_bonus = speed_bonus * 0.85  -- Additional 15% faster (38.6% total)
  end
  if force.technologies["interplanetary-logistics-speed-4"] and force.technologies["interplanetary-logistics-speed-4"].researched then
    speed_bonus = speed_bonus * 0.8   -- Additional 20% faster (50.9% total)
  end

  return speed_bonus
end


-- Remove emission effects
local function remove_transfer_emissions(entity)
  if not entity or not entity.valid then return end

  local unit_number = entity.unit_number
  local emissions = storage.active_emissions[unit_number]

  if emissions then
    if emissions.emission and emissions.emission.valid then
      emissions.emission.destroy()
    end
    if emissions.light and emissions.light.valid then
      emissions.light.destroy()
    end
    storage.active_emissions[unit_number] = nil
  end
end


-- Create animation entity for a container
local function create_animation_entity(container, is_active)
  if not container or not container.valid then return nil end

  local animation_name
  local state_suffix = is_active and "-active" or "-idle"

  if container.name == "interplanetary-provider-chest" then
    animation_name = "interplanetary-provider-animation" .. state_suffix
  elseif container.name == "interplanetary-requester-chest" then
    animation_name = "interplanetary-requester-animation" .. state_suffix
  else
    return nil
  end

  local animation_entity = container.surface.create_entity{
    name = animation_name,
    position = container.position,
    force = container.force
  }

  if animation_entity then
    animation_entity.destructible = false
  end

  return animation_entity
end

-- Switch animation state for a chest
local function set_animation_state(chest_data, is_active)
  if not chest_data or not chest_data.entity or not chest_data.entity.valid then return end

  -- Destroy current animation entity if it exists
  if chest_data.animation_entity and chest_data.animation_entity.valid then
    chest_data.animation_entity.destroy()
  end

  -- Create new animation entity with the desired state
  chest_data.animation_entity = create_animation_entity(chest_data.entity, is_active)
end

-- Set up chest after placement
local function setup_chest(entity)
  if not entity or not entity.valid then return end

  local chest_data = storage.interplanetary_chests[entity.unit_number]
  if chest_data then
    -- Start with idle animation
    set_animation_state(chest_data, false)
  end
end

-- Register interplanetary chests when built
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
  local entity = event.entity
  if entity and entity.valid then
    -- Skip our invisible entities to prevent infinite loops
    if entity.name == "interplanetary-roboport" or entity.name == "interplanetary-provider-power-interface" or entity.name == "interplanetary-requester-power-interface" then
      return
    end

    if entity.name == "interplanetary-provider-chest" or entity.name == "interplanetary-requester-chest" then
      -- Track for custom logistics
      storage.interplanetary_chests[entity.unit_number] = {
        entity = entity,
        type = entity.name
      }
      -- Set up the chest
      setup_chest(entity)
    end
  end
end)

-- Clean up when chests are destroyed
script.on_event({
  defines.events.on_entity_died,
  defines.events.on_pre_player_mined_item,
  defines.events.on_robot_pre_mined,
  defines.events.script_raised_destroy
}, function(event)
  local entity = event.entity
  if entity and entity.valid and entity.unit_number then
    local chest_data = storage.interplanetary_chests[entity.unit_number]
    if chest_data then
      -- Clean up emissions and transfer data
      remove_transfer_emissions(entity)
      storage.transfer_cooldowns[entity.unit_number] = nil

      -- Clean up animation entity
      if chest_data.animation_entity and chest_data.animation_entity.valid then
        chest_data.animation_entity.destroy()
      end

      storage.interplanetary_chests[entity.unit_number] = nil
    end
  end
end)

-- Process emission timers and cleanup
local function process_emission_timers()
  if not storage.emission_timers then return end

  for unit_number, end_tick in pairs(storage.emission_timers) do
    if game.tick >= end_tick then
      -- Timer expired, clean up
      storage.emission_timers[unit_number] = nil
    end
  end
end

-- Process active transfer timers and switch animations back to idle
local function process_active_transfers()
  if not storage.active_transfers then return end

  for unit_number, end_tick in pairs(storage.active_transfers) do
    if game.tick >= end_tick then
      -- Transfer finished, switch back to idle animation
      local chest_data = storage.interplanetary_chests[unit_number]
      if chest_data then
        set_animation_state(chest_data, false)
      end
      storage.active_transfers[unit_number] = nil
    end
  end
end

-- Process pending transfers from previous tick
script.on_nth_tick(1, function()
  -- Ensure storage is initialized
  init_storage()
  process_emission_timers()
  process_active_transfers()

  if not storage.pending_transfers then return end

  for transfer_id, transfer_data in pairs(storage.pending_transfers) do
    if transfer_data.created_tick + 5 <= game.tick then -- Wait 5 ticks for network connection
      local provider_interface = transfer_data.provider_interface
      local buffer_interface = transfer_data.buffer_interface

      if provider_interface and provider_interface.valid and buffer_interface and buffer_interface.valid then
        local provider_energy = provider_interface.energy or 0
        local buffer_energy = buffer_interface.energy or 0
        -- game.print("Processing transfer " .. transfer_id .. " - Provider energy: " .. provider_energy .. ", Buffer energy: " .. buffer_energy)


        -- game.print("Power needed - Sending: " .. transfer_data.sending_power_needed .. ", Receiving: " .. transfer_data.receiving_power_needed)
        if provider_energy >= transfer_data.sending_power_needed and buffer_energy >= transfer_data.receiving_power_needed then
          -- Consume power
          provider_interface.energy = provider_energy - transfer_data.sending_power_needed
          buffer_interface.energy = buffer_energy - transfer_data.receiving_power_needed

          -- Transfer items
          local removed = transfer_data.provider.remove_item{name = transfer_data.item_name, count = transfer_data.stack_size} or 0
          -- game.print("Attempting to transfer " .. transfer_data.stack_size .. " " .. transfer_data.item_name .. " - Removed: " .. removed)
          if removed == transfer_data.stack_size then
            local inserted = transfer_data.buffer.insert{name = transfer_data.item_name, count = transfer_data.stack_size} or 0
            -- game.print("Inserted: " .. inserted .. " into buffer")
            if inserted == transfer_data.stack_size then
              storage.transfer_cooldowns[transfer_data.buffer_id] = game.tick + transfer_data.transfer_duration
              -- game.print("Transfer successful! Cooldown set.")

              -- Mark both chests as active for transfer duration
              local provider_unit = transfer_data.provider.unit_number
              local buffer_unit = transfer_data.buffer.unit_number
              local end_tick = game.tick + transfer_data.transfer_duration

              storage.active_transfers[provider_unit] = end_tick
              storage.active_transfers[buffer_unit] = end_tick

              -- Switch animations to active state
              local provider_data = storage.interplanetary_chests[provider_unit]
              local buffer_data = storage.interplanetary_chests[buffer_unit]
              if provider_data then set_animation_state(provider_data, true) end
              if buffer_data then set_animation_state(buffer_data, true) end
            else
              transfer_data.provider.insert{name = transfer_data.item_name, count = transfer_data.stack_size}
            end
          end

          -- Schedule cleanup after transfer duration
          storage.emission_timers[transfer_data.provider.unit_number] = game.tick + transfer_data.transfer_duration
          storage.emission_timers[transfer_data.buffer.unit_number] = game.tick + transfer_data.transfer_duration
        end
      end

      -- Clean up
      -- game.print("Cleaning up transfer " .. transfer_id)
      if provider_interface and provider_interface.valid then provider_interface.destroy() end
      if buffer_interface and buffer_interface.valid then buffer_interface.destroy() end
      storage.pending_transfers[transfer_id] = nil
    end
  end
end)

-- Process interplanetary logistics and isolate from regular networks
script.on_nth_tick(60, function()
  pcall(function()
    -- Ensure storage is initialized
    init_storage()

    if not storage.interplanetary_chests then return end

    -- Separate tracked interplanetary chests by type
    local all_providers = {}
    local all_buffers = {}

    for unit_number, chest_data in pairs(storage.interplanetary_chests) do
      if chest_data.entity and chest_data.entity.valid then
        if chest_data.type == "interplanetary-provider-chest" then
          table.insert(all_providers, chest_data.entity)
        elseif chest_data.type == "interplanetary-requester-chest" then
          table.insert(all_buffers, chest_data.entity)
        end
      else
        -- Clean up invalid entities
        storage.interplanetary_chests[unit_number] = nil
      end
    end


    -- Process interplanetary logistics: providers → buffers only
    for _, buffer in pairs(all_buffers) do
      if buffer and buffer.valid then
        local buffer_id = buffer.unit_number
        local current_tick = game.tick

        local power_settings = get_power_settings()

        -- Check transfer cooldown
        if storage.transfer_cooldowns[buffer_id] and
           current_tick < storage.transfer_cooldowns[buffer_id] then
          -- Still on cooldown, skip this buffer
          goto continue_buffer
        end

        -- Check buffer requests and fulfill from interplanetary providers
        pcall(function()
          local logistic_point = buffer.get_logistic_point(defines.logistic_member_index.logistic_container)
          if logistic_point then
            local sections = logistic_point.sections

            for _, section in pairs(sections) do
              local filters = section.filters
              for _, filter in pairs(filters) do
                if filter.value and filter.value.name then
                  local item_name = filter.value.name
                  local requested = filter.min or 0
                  local current = buffer.get_item_count(item_name) or 0
                  local needed = requested - current
                  local stack_size = prototypes.item[item_name].stack_size
                  -- game.print("Buffer " .. buffer.unit_number .. " needs " .. needed .. " " .. item_name .. " (has " .. current .. ", wants " .. requested .. ")")

                  if needed >= stack_size then
                    -- Check if there's already a pending transfer for this buffer
                    local has_pending_transfer = false
                    for _, transfer_data in pairs(storage.pending_transfers) do
                      if transfer_data.buffer_id == buffer_id then
                        has_pending_transfer = true
                        break
                      end
                    end

                    if not has_pending_transfer then
                      -- Look for this item in interplanetary providers only
                      for _, provider in pairs(all_providers) do
                        if provider and provider.valid and provider ~= buffer then
                          local available = provider.get_item_count(item_name) or 0
                          if available >= stack_size then
                            -- Apply quality efficiency bonuses
                            local provider_efficiency = get_quality_efficiency(provider)
                            local buffer_efficiency = get_quality_efficiency(buffer)

                          -- Apply speed bonuses (quality + research)
                          local provider_speed_bonus = get_quality_speed_bonus(provider)
                          local buffer_speed_bonus = get_quality_speed_bonus(buffer)
                          local research_speed_bonus = get_research_speed_bonus(provider.force)

                          -- Use the best speed bonus between provider and buffer
                          local total_speed_bonus = math.min(provider_speed_bonus, buffer_speed_bonus) * research_speed_bonus
                          local adjusted_duration = power_settings.transfer_duration * total_speed_bonus

                          local sending_power_needed = power_settings.sending_power * adjusted_duration / 60 * provider_efficiency
                          local receiving_power_needed = power_settings.receiving_power * adjusted_duration / 60 * buffer_efficiency

                          -- Create temporary power interfaces for this transfer
                          local provider_interface = provider.surface.create_entity{
                            name = "interplanetary-provider-power-interface",
                            position = {x = provider.position.x + 0.1, y = provider.position.y + 0.1},
                            force = provider.force,
                            quality = provider.quality
                          }

                          local buffer_interface = buffer.surface.create_entity{
                            name = "interplanetary-requester-power-interface",
                            position = {x = buffer.position.x + 0.1, y = buffer.position.y + 0.1},
                            force = buffer.force,
                            quality = buffer.quality
                          }

                          if provider_interface and buffer_interface then
                            -- Create pending transfer to process after interfaces connect to network
                            local transfer_id = provider.unit_number .. "_" .. buffer.unit_number .. "_" .. current_tick
                            storage.pending_transfers[transfer_id] = {
                              provider = provider,
                              buffer = buffer,
                              buffer_id = buffer_id,
                              item_name = item_name,
                              stack_size = stack_size,
                              sending_power_needed = sending_power_needed,
                              receiving_power_needed = receiving_power_needed,
                              transfer_duration = adjusted_duration,
                              provider_interface = provider_interface,
                              buffer_interface = buffer_interface,
                              created_tick = current_tick
                            }

                            goto transfer_complete
                          else
                            if provider_interface then provider_interface.destroy() end
                            if buffer_interface then buffer_interface.destroy() end
                          end
                        end
                      end
                    end
                    end
                  end
                end
              end
            end
          end
          ::transfer_complete::
        end)
        ::continue_buffer::
      end
    end

    -- Note: Local network interference with buffer requests is difficult to prevent
    -- without breaking the UI. The interplanetary system runs every 60 ticks and 
    -- should generally be faster than local logistics.

  end)
end)

-- Handle entity movement (dolly compatibility)
script.on_event(defines.events.script_raised_teleported, function(event)
  local entity = event.entity
  if entity and entity.valid and (entity.name == "interplanetary-provider-chest" or entity.name == "interplanetary-requester-chest") then
    local chest_data = storage.interplanetary_chests[entity.unit_number]
    if chest_data and chest_data.animation_entity and chest_data.animation_entity.valid then
      -- Move animation entity to match container position
      chest_data.animation_entity.teleport(entity.position)
    end
  end
end)

-- Handle entity cloning (also used by some movement mods)
script.on_event(defines.events.on_entity_cloned, function(event)
  local source = event.source
  local destination = event.destination

  if source and source.valid and destination and destination.valid and
     (source.name == "interplanetary-provider-chest" or source.name == "interplanetary-requester-chest") then

    local source_data = storage.interplanetary_chests[source.unit_number]
    if source_data then
      -- Create new chest data for the cloned entity
      storage.interplanetary_chests[destination.unit_number] = {
        entity = destination,
        type = destination.name
      }

      -- Set up animation for the new entity
      setup_chest(destination)

      -- Clean up old animation if it exists
      if source_data.animation_entity and source_data.animation_entity.valid then
        source_data.animation_entity.destroy()
      end

      -- Remove old chest data
      storage.interplanetary_chests[source.unit_number] = nil
    end
  end
end)
