local Settings = require("__interplanetary-logistics-network__.settings_util")
local State = require("__interplanetary-logistics-network__.state")

local M = {}

local function quality_efficiency(entity)
  if not entity or not entity.valid then return 1.0 end
  local q = (entity.quality and entity.quality.name) or "normal"
  local map = { normal = 1.0, uncommon = 0.85, rare = 0.7, epic = 0.5, legendary = 0.3 }
  return map[q] or 1.0
end

local function quality_speed(entity)
  if not entity or not entity.valid then return 1.0 end
  local q = (entity.quality and entity.quality.name) or "normal"
  local map = { normal = 1.0, uncommon = 0.9, rare = 0.75, epic = 0.6, legendary = 0.4 }
  return map[q] or 1.0
end

local function research_speed(force)
  if not force or not force.valid then return 1.0 end
  local m = 1.0
  if force.technologies["interplanetary-logistics-speed-1"] and force.technologies["interplanetary-logistics-speed-1"].researched then m = m * 0.85 end
  if force.technologies["interplanetary-logistics-speed-2"] and force.technologies["interplanetary-logistics-speed-2"].researched then m = m * 0.85 end
  if force.technologies["interplanetary-logistics-speed-3"] and force.technologies["interplanetary-logistics-speed-3"].researched then m = m * 0.85 end
  if force.technologies["interplanetary-logistics-speed-4"] and force.technologies["interplanetary-logistics-speed-4"].researched then m = m * 0.8 end
  return m
end

local function set_animation_state(chest_data, is_active)
  if not chest_data or not chest_data.entity or not chest_data.entity.valid then return end
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
  if e then e.destructible = false end
  chest_data.animation_entity = e
end

local function show_power_failure(entity, sp, rp, sa, ra)
  if not entity or not entity.valid then return end
  local id = entity.unit_number
  local now = game.tick
  storage.power_failure_counts[id] = (storage.power_failure_counts[id] or 0) + 1
  local count = storage.power_failure_counts[id]
  local text = "⚡ Insufficient Power!"
  local offs = { { 0.015, 0 }, { -0.015, 0 }, { 0, 0.015 }, { 0, -0.015 } }
  for _, o in pairs(offs) do
    rendering.draw_text { text = text, surface = entity.surface, target = { entity.position.x + o[1], entity.position.y - 2 + o[2] }, color = { r = 0, g = 0, b = 0, a = 0.8 }, scale = 1.0, font = "default-bold", time_to_live = 60, alignment = "center" }
  end
  rendering.draw_text { text = text, surface = entity.surface, target = { entity.position.x, entity.position.y - 2 }, color = { r = 1, g = 0.2, b = 0.2 }, scale = 1.0, font = "default-bold", time_to_live = 120, alignment = "center" }
  local last = storage.power_failure_notifications[id] or 0
  if now - last > 1800 then
    storage.power_failure_notifications[id] = now
    entity.force.print("[color=red]Interplanetary transfer failed at [gps=" .. math.floor(entity.position.x) .. "," .. math.floor(entity.position.y) .. "," .. entity.surface.name .. "]: Need " .. string.format("%.1f", sp / 1000000) .. "MJ (sending) + " .. string.format("%.1f", rp / 1000000) .. "MJ (receiving), but only " .. string.format("%.1f", sa / 1000000) .. "MJ + " .. string.format("%.1f", ra / 1000000) .. "MJ available[/color]")
    if count >= 5 then entity.force.print("[color=yellow]Tip: Consider more power or slower transfer speed[/color]") end
  end
end

local function reset_failure(entity)
  if entity and entity.valid and entity.unit_number then storage.power_failure_counts[entity.unit_number] = nil end
end

function M.register_chest(entity)
  storage.interplanetary_chests[entity.unit_number] = { entity = entity, type = entity.name }
  set_animation_state(storage.interplanetary_chests[entity.unit_number], false)
end

local function process_emission_timers()
  for unit_number, end_tick in pairs(storage.emission_timers) do
    if game.tick >= end_tick then storage.emission_timers[unit_number] = nil end
  end
end

local function process_active_transfers()
  for unit_number, end_tick in pairs(storage.active_transfers) do
    if game.tick >= end_tick then
      local chest_data = storage.interplanetary_chests[unit_number]
      if chest_data then set_animation_state(chest_data, false) end
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
      if pi and pi.valid and bi and bi.valid then
        local pe = pi.energy or 0
        local be = bi.energy or 0
        if pe >= t.sending_power_needed and be >= t.receiving_power_needed then
          pi.energy = pe - t.sending_power_needed
          bi.energy = be - t.receiving_power_needed
          local removed = t.provider.remove_item { name = t.item_name, count = t.stack_size } or 0
          if removed == t.stack_size then
            local inserted = t.buffer.insert { name = t.item_name, count = t.stack_size } or 0
            if inserted == t.stack_size then
              storage.transfer_cooldowns[t.buffer_id] = game.tick + t.transfer_duration
              reset_failure(t.provider)
              reset_failure(t.buffer)
              local pend = game.tick + t.transfer_duration
              storage.active_transfers[t.provider.unit_number] = pend
              storage.active_transfers[t.buffer.unit_number] = pend
              local pd = storage.interplanetary_chests[t.provider.unit_number]
              local bd = storage.interplanetary_chests[t.buffer.unit_number]
              if pd then set_animation_state(pd, true) end
              if bd then set_animation_state(bd, true) end
            else
              t.provider.insert { name = t.item_name, count = t.stack_size }
            end
          end
          storage.emission_timers[t.provider.unit_number] = game.tick + t.transfer_duration
          storage.emission_timers[t.buffer.unit_number] = game.tick + t.transfer_duration
        else
          local chest = t.buffer
          if pe < t.sending_power_needed then chest = t.provider end
          show_power_failure(chest, t.sending_power_needed, t.receiving_power_needed, pe, be)
        end
      end
      if pi and pi.valid then pi.destroy() end
      if bi and bi.valid then bi.destroy() end
      storage.pending_transfers[id] = nil
    end
  end
end

function M.on_slow_tick()
  State.init()
  if not storage.interplanetary_chests then return end
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
      if storage.transfer_cooldowns[id] and now < storage.transfer_cooldowns[id] then goto continue end
      local ok, err = pcall(function()
        local lp = buffer.get_logistic_point(defines.logistic_member_index.logistic_container)
        if not lp then return end
        for _, section in pairs(lp.sections) do
          for _, filter in pairs(section.filters) do
            if filter.value and filter.value.name then
              local item = filter.value.name
              local req = filter.min or 0
              local cur = buffer.get_item_count(item) or 0
              local need = req - cur
              if need <= 0 then goto next_filter end
              local stack = prototypes.item[item].stack_size
              if need < stack then goto next_filter end
              local pending = false
              for _, t in pairs(storage.pending_transfers) do if t.buffer_id == id then pending = true; break end end
              if pending then goto next_filter end
              for _, provider in pairs(providers) do
                if provider and provider.valid and provider ~= buffer then
                  local avail = provider.get_item_count(item) or 0
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
                    local pi = provider.surface.create_entity { name = "interplanetary-provider-power-interface", position = { x = provider.position.x + 0.1, y = provider.position.y + 0.1 }, force = provider.force, quality = provider.quality }
                    local bi = buffer.surface.create_entity { name = "interplanetary-requester-power-interface", position = { x = buffer.position.x + 0.1, y = buffer.position.y + 0.1 }, force = buffer.force, quality = buffer.quality }
                    if pi and bi then
                      local tid = provider.unit_number .. "_" .. buffer.unit_number .. "_" .. now
                      storage.pending_transfers[tid] = { provider = provider, buffer = buffer, buffer_id = id, item_name = item, stack_size = stack, sending_power_needed = sp, receiving_power_needed = rp, transfer_duration = duration, provider_interface = pi, buffer_interface = bi, created_tick = now }
                      goto next_filter
                    else
                      if pi then pi.destroy() end
                      if bi then bi.destroy() end
                    end
                  end
                end
              end
            end
            ::next_filter::
          end
        end
      end)
      if not ok then log("transfer on_slow_tick error: " .. tostring(err)) end
    end
    ::continue::
  end
end

return M
