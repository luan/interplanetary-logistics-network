local Settings = require "__interplanetary-logistics-network__.settings_util"
local State = require "__interplanetary-logistics-network__.state"

local M = {}

-- Reservation helpers to avoid over-committing items across multiple pending transfers
local function get_reserved_total(provider_unit_number, item_name)
  local per_provider = storage.item_reservations and storage.item_reservations[provider_unit_number]
  local rec = per_provider and per_provider[item_name]
  return (rec and rec.total) or 0
end

local function add_reservation(provider_entity, item_name, count, transfer_id)
  if not (provider_entity and provider_entity.valid and transfer_id and item_name and count and count > 0) then
    return
  end
  storage.item_reservations = storage.item_reservations or {}
  storage.reservations_by_transfer = storage.reservations_by_transfer or {}
  local pu = provider_entity.unit_number
  storage.item_reservations[pu] = storage.item_reservations[pu] or {}
  local rec = storage.item_reservations[pu][item_name]
  if not rec then
    rec = { total = 0, by = {} }
    storage.item_reservations[pu][item_name] = rec
  end
  rec.total = rec.total + count
  rec.by[transfer_id] = (rec.by[transfer_id] or 0) + count
  storage.reservations_by_transfer[transfer_id] = storage.reservations_by_transfer[transfer_id] or {}
  table.insert(
    storage.reservations_by_transfer[transfer_id],
    { provider_unit = pu, item_name = item_name, count = count }
  )
end

local function release_reservation_by_transfer(transfer_id)
  if not transfer_id then
    return
  end
  local entries = storage.reservations_by_transfer and storage.reservations_by_transfer[transfer_id]
  if not entries then
    return
  end
  for _, e in pairs(entries) do
    local pu = e.provider_unit
    local item = e.item_name
    local count = e.count or 0
    local per_provider = storage.item_reservations and storage.item_reservations[pu]
    local rec = per_provider and per_provider[item]
    if rec then
      local tid_count = rec.by and rec.by[transfer_id] or 0
      local delta = math.min(count, tid_count)
      if delta > 0 then
        rec.total = math.max(0, (rec.total or 0) - delta)
        rec.by[transfer_id] = tid_count - delta
        if rec.by[transfer_id] <= 0 then
          rec.by[transfer_id] = nil
        end
      end
      if (rec.total or 0) <= 0 and (not rec.by or next(rec.by) == nil) then
        per_provider[item] = nil
      end
      if next(per_provider) == nil then
        storage.item_reservations[pu] = nil
      end
    end
  end
  storage.reservations_by_transfer[transfer_id] = nil
end

local function quality_efficiency(entity)
  if not entity or not entity.valid then
    return 1.0
  end
  local q = (entity.quality and entity.quality.name) or "normal"
  local map = { normal = 1.0, uncommon = 0.85, rare = 0.7, epic = 0.5, legendary = 0.3 }
  return map[q] or 1.0
end

local function quality_speed(entity)
  if not entity or not entity.valid then
    return 1.0
  end
  local q = (entity.quality and entity.quality.name) or "normal"
  local map = { normal = 1.0, uncommon = 0.9, rare = 0.75, epic = 0.6, legendary = 0.4 }
  return map[q] or 1.0
end

local function research_speed(force)
  if not force or not force.valid then
    return 1.0
  end
  local m = 1.0
  if
    force.technologies["interplanetary-logistics-speed-1"]
    and force.technologies["interplanetary-logistics-speed-1"].researched
  then
    m = m * 0.85
  end
  if
    force.technologies["interplanetary-logistics-speed-2"]
    and force.technologies["interplanetary-logistics-speed-2"].researched
  then
    m = m * 0.85
  end
  if
    force.technologies["interplanetary-logistics-speed-3"]
    and force.technologies["interplanetary-logistics-speed-3"].researched
  then
    m = m * 0.85
  end
  if
    force.technologies["interplanetary-logistics-speed-4"]
    and force.technologies["interplanetary-logistics-speed-4"].researched
  then
    m = m * 0.8
  end
  return m
end

local function set_animation_state(chest_data, is_active)
  if not chest_data or not chest_data.entity or not chest_data.entity.valid then
    return
  end
  if chest_data.animation_entity and chest_data.animation_entity.valid then
    chest_data.animation_entity.destroy()
  end
  local container = chest_data.entity
  local state_suffix = is_active and "-active" or "-idle"
  local anim
  if container.name == "interplanetary-provider-chest" then
    anim = "interplanetary-provider-animation" .. state_suffix
  elseif container.name == "interplanetary-requester-chest" then
    anim = "interplanetary-requester-animation" .. state_suffix
  else
    return
  end
  local e = container.surface.create_entity { name = anim, position = container.position, force = container.force }
  if e then
    e.destructible = false
  end
  chest_data.animation_entity = e
end

local function show_power_failure(entity, sp, rp, sa, ra)
  if not entity or not entity.valid then
    return
  end
  local id = entity.unit_number
  local now = game.tick
  storage.power_failure_counts[id] = (storage.power_failure_counts[id] or 0) + 1
  local count = storage.power_failure_counts[id]
  local text = "⚡ Insufficient Power!"
  local offs = { { 0.015, 0 }, { -0.015, 0 }, { 0, 0.015 }, { 0, -0.015 } }
  for _, o in pairs(offs) do
    rendering.draw_text {
      text = text,
      surface = entity.surface,
      target = { entity.position.x + o[1], entity.position.y - 2 + o[2] },
      color = { r = 0, g = 0, b = 0, a = 0.8 },
      scale = 1.0,
      font = "default-bold",
      time_to_live = 60,
      alignment = "center",
    }
  end
  rendering.draw_text {
    text = text,
    surface = entity.surface,
    target = { entity.position.x, entity.position.y - 2 },
    color = { r = 1, g = 0.2, b = 0.2 },
    scale = 1.0,
    font = "default-bold",
    time_to_live = 120,
    alignment = "center",
  }
  local last = storage.power_failure_notifications[id] or 0
  if now - last > 1800 then
    storage.power_failure_notifications[id] = now
    entity.force.print(
      "[color=red]Interplanetary transfer failed at [gps="
        .. math.floor(entity.position.x)
        .. ","
        .. math.floor(entity.position.y)
        .. ","
        .. entity.surface.name
        .. "]: Need "
        .. string.format("%.1f", sp / 1000000)
        .. "MJ (sending) + "
        .. string.format("%.1f", rp / 1000000)
        .. "MJ (receiving), but only "
        .. string.format("%.1f", sa / 1000000)
        .. "MJ + "
        .. string.format("%.1f", ra / 1000000)
        .. "MJ available[/color]"
    )
    if count >= 5 then
      entity.force.print "[color=yellow]Tip: Consider more power or slower transfer speed[/color]"
    end
  end
end

local function reset_failure(entity)
  if entity and entity.valid and entity.unit_number then
    storage.power_failure_counts[entity.unit_number] = nil
  end
end

function M.register_chest(entity)
  storage.interplanetary_chests[entity.unit_number] = { entity = entity, type = entity.name }
  set_animation_state(storage.interplanetary_chests[entity.unit_number], false)
end

local function process_emission_timers()
  for unit_number, end_tick in pairs(storage.emission_timers) do
    if game.tick >= end_tick then
      storage.emission_timers[unit_number] = nil
    end
  end
end

local function process_active_transfers()
  for unit_number, end_tick in pairs(storage.active_transfers) do
    if game.tick >= end_tick then
      local chest_data = storage.interplanetary_chests[unit_number]
      if chest_data then
        set_animation_state(chest_data, false)
      end
      storage.active_transfers[unit_number] = nil
    end
  end
end

function M.on_fast_tick()
  State.init()
  process_emission_timers()
  process_active_transfers()
  for id, t in pairs(storage.pending_transfers) do
    if t.created_tick + 5 <= game.tick then
      local pi = t.provider_interface
      local bi = t.buffer_interface
      local provider_valid = t.provider and t.provider.valid
      local buffer_valid = t.buffer and t.buffer.valid
      if not provider_valid or not buffer_valid then
        if pi and pi.valid then
          pi.destroy()
        end
        if bi and bi.valid then
          bi.destroy()
        end
        release_reservation_by_transfer(id)
        storage.pending_transfers[id] = nil
      elseif pi and pi.valid and bi and bi.valid then
        local pe = pi.energy or 0
        local be = bi.energy or 0

        -- Initialize streaming fields for backward compatibility
        t.sending_energy_remaining = t.sending_energy_remaining or t.sending_power_needed
        t.receiving_energy_remaining = t.receiving_energy_remaining or t.receiving_power_needed
        t.sending_energy_per_tick = t.sending_energy_per_tick
          or math.max(0, (t.sending_power_needed / t.transfer_duration))
        t.receiving_energy_per_tick = t.receiving_energy_per_tick
          or math.max(0, (t.receiving_power_needed / t.transfer_duration))

        local drained = false

        -- Drain provider side
        if t.sending_energy_remaining > 0 and pe > 0 then
          local drain_s = math.min(pe, t.sending_energy_remaining, t.sending_energy_per_tick)
          if drain_s > 0 then
            pi.energy = pe - drain_s
            t.sending_energy_remaining = t.sending_energy_remaining - drain_s
            drained = true
          end
        end

        -- Drain receiver side
        if t.receiving_energy_remaining > 0 and be > 0 then
          local drain_r = math.min(be, t.receiving_energy_remaining, t.receiving_energy_per_tick)
          if drain_r > 0 then
            bi.energy = be - drain_r
            t.receiving_energy_remaining = t.receiving_energy_remaining - drain_r
            drained = true
          end
        end

        if t.sending_energy_remaining <= 0 and t.receiving_energy_remaining <= 0 then
          -- Energy fully paid: perform transfer and clean up
          local removed = t.provider.remove_item { name = t.item_name, count = t.stack_size } or 0
          if removed < t.stack_size then
            -- Not enough items at provider anymore: return anything that was removed
            if removed > 0 then
              local returned = t.provider.insert { name = t.item_name, count = removed } or 0
              local spill = removed - returned
              if spill > 0 then
                t.provider.surface.spill_item_stack(
                  t.provider.position,
                  { name = t.item_name, count = spill },
                  true,
                  t.provider.force,
                  false
                )
              end
            end
            release_reservation_by_transfer(id)
          else
            -- We removed a full stack; attempt to insert on the buffer
            local inserted = t.buffer.insert { name = t.item_name, count = removed } or 0
            if inserted == removed then
              storage.transfer_cooldowns[t.buffer_id] = storage.transfer_cooldowns[t.buffer_id] or {}
              storage.transfer_cooldowns[t.buffer_id][t.item_name] = game.tick + t.transfer_duration
              reset_failure(t.provider)
              reset_failure(t.buffer)
              local pend = game.tick + t.transfer_duration
              storage.active_transfers[t.provider.unit_number] = pend
              storage.active_transfers[t.buffer.unit_number] = pend
              local pd = storage.interplanetary_chests[t.provider.unit_number]
              local bd = storage.interplanetary_chests[t.buffer.unit_number]
              if pd then
                set_animation_state(pd, true)
              end
              if bd then
                set_animation_state(bd, true)
              end
              release_reservation_by_transfer(id)
            else
              -- Partial insertion: return the remainder to the provider
              local to_return = removed - inserted
              if to_return > 0 then
                local returned = t.provider.insert { name = t.item_name, count = to_return } or 0
                local spill = to_return - returned
                if spill > 0 then
                  t.provider.surface.spill_item_stack(
                    t.provider.position,
                    { name = t.item_name, count = spill },
                    true,
                    t.provider.force,
                    false
                  )
                end
              end
              release_reservation_by_transfer(id)
            end
          end
          storage.emission_timers[t.provider.unit_number] = game.tick + t.transfer_duration
          storage.emission_timers[t.buffer.unit_number] = game.tick + t.transfer_duration

          if pi and pi.valid then
            pi.destroy()
          end
          if bi and bi.valid then
            bi.destroy()
          end
          storage.pending_transfers[id] = nil
        else
          -- Not fully paid yet: keep interfaces
          -- Show warning only if we made no progress recently
          if not drained then
            local now = game.tick
            local last_warn = t.last_warning_tick or 0
            if now - last_warn >= 120 then
              local chest = t.buffer
              if (t.sending_energy_remaining or 0) > (t.receiving_energy_remaining or 0) then
                chest = t.provider
              end
              show_power_failure(chest, t.sending_energy_remaining, t.receiving_energy_remaining, pe, be)
              t.last_warning_tick = now
            end
          end
        end
      else
        -- Interfaces got removed externally; clean up this pending transfer
        if pi and pi.valid then
          pi.destroy()
        end
        if bi and bi.valid then
          bi.destroy()
        end
        release_reservation_by_transfer(id)
        storage.pending_transfers[id] = nil
      end
    end
  end
end

function M.on_slow_tick()
  State.init()
  if not storage.interplanetary_chests then
    return
  end
  local providers = {}
  local buffers = {}
  for unit_number, data in pairs(storage.interplanetary_chests) do
    if data.entity and data.entity.valid then
      if data.type == "interplanetary-provider-chest" then
        providers[#providers + 1] = data.entity
      elseif data.type == "interplanetary-requester-chest" then
        buffers[#buffers + 1] = data.entity
      end
    else
      storage.interplanetary_chests[unit_number] = nil
    end
  end
  local power = Settings.get()
  for _, buffer in pairs(buffers) do
    if buffer and buffer.valid then
      local id = buffer.unit_number
      local now = game.tick
      local ok, err = pcall(function()
        local lp = buffer.get_logistic_point(defines.logistic_member_index.logistic_container)
        if not lp then
          return
        end
        for _, section in pairs(lp.sections) do
          for _, filter in pairs(section.filters) do
            if filter.value and filter.value.name then
              local item = filter.value.name
              local req = filter.min or 0
              local cur = buffer.get_item_count(item) or 0
              local need = req - cur
              if need <= 0 then
                goto next_filter
              end
              local stack = prototypes.item[item].stack_size
              if need < stack then
                goto next_filter
              end
              -- Per-item cooldown gate
              if
                storage.transfer_cooldowns[id]
                and storage.transfer_cooldowns[id][item]
                and now < storage.transfer_cooldowns[id][item]
              then
                goto next_filter
              end
              local pending = false
              for _, t in pairs(storage.pending_transfers) do
                if t.buffer_id == id and t.item_name == item then
                  pending = true
                  break
                end
              end
              if pending then
                goto next_filter
              end
              for _, provider in pairs(providers) do
                if provider and provider.valid and provider ~= buffer then
                  local avail = (provider.get_item_count(item) or 0) - get_reserved_total(provider.unit_number, item)
                  if avail >= stack then
                    local pef = quality_efficiency(provider)
                    local bef = quality_efficiency(buffer)
                    local ps = quality_speed(provider)
                    local bs = quality_speed(buffer)
                    local rs = research_speed(provider.force)
                    local speed = math.min(ps, bs) * rs
                    local duration = power.transfer_duration * speed
                    local sp = power.sending_power * duration / 60 * pef
                    local rp = power.receiving_power * duration / 60 * bef
                    local pi = provider.surface.create_entity {
                      name = "interplanetary-provider-power-interface",
                      position = { x = provider.position.x + 0.1, y = provider.position.y + 0.1 },
                      force = provider.force,
                      quality = provider.quality,
                    }
                    local bi = buffer.surface.create_entity {
                      name = "interplanetary-requester-power-interface",
                      position = { x = buffer.position.x + 0.1, y = buffer.position.y + 0.1 },
                      force = buffer.force,
                      quality = buffer.quality,
                    }
                    if pi and bi then
                      local tid = provider.unit_number .. "_" .. buffer.unit_number .. "_" .. now
                      storage.pending_transfers[tid] = {
                        provider = provider,
                        buffer = buffer,
                        buffer_id = id,
                        item_name = item,
                        stack_size = stack,
                        sending_power_needed = sp,
                        receiving_power_needed = rp,
                        transfer_duration = duration,
                        provider_interface = pi,
                        buffer_interface = bi,
                        created_tick = now,
                      }
                      add_reservation(provider, item, stack, tid)
                      goto next_filter
                    else
                      if pi then
                        pi.destroy()
                      end
                      if bi then
                        bi.destroy()
                      end
                    end
                  end
                end
              end
            end
            ::next_filter::
          end
        end
      end)
      if not ok then
        log("transfer on_slow_tick error: " .. tostring(err))
      end
    end
    ::continue::
  end
end

return M
