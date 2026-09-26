local function assert_equal(actual, expected, label)
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function surface(name)
  local result = game.create_surface(name, {
    width = 128,
    height = 128,
    water = 0,
    autoplace_settings = {
      entity = { treat_missing_as_default = false },
      decorative = { treat_missing_as_default = false },
    },
  })
  result.request_to_generate_chunks({ 0, 0 }, 2)
  result.force_generate_chunk_requests()
  local tiles = {}
  for x = -60, 60 do
    for y = -60, 60 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  result.set_tiles(tiles)
  result.freeze_daytime = true
  result.daytime = 0
  return result
end

local function build(name, target, position, options, force)
  if options then
    local ghost = assert(target.create_entity {
      name = "entity-ghost",
      inner_name = name,
      position = position,
      force = force or "player",
      tags = { iln = options },
    })
    local _, entity = ghost.revive { raise_revive = true }
    return assert(entity, "Tagged blueprint ghost revived")
  end
  return assert(
    target.create_entity { name = name, position = position, force = force or "player", raise_built = true }
  )
end

local function chest(kind, target, options, force)
  storage.next_position = storage.next_position + 1
  local n = storage.next_position
  return build(
    "interplanetary-" .. kind .. "-chest",
    target,
    { -48 + n % 20 * 5, -45 + math.floor(n / 20) * 8 },
    options,
    force
  )
end

local function request(entity, name, count, quality, section)
  local sections = entity.get_logistic_sections()
  local group = section or sections.add_section()
  group.set_slot(
    #group.filters + 1,
    { value = { name = name, quality = quality or "normal", comparator = "=" }, min = count }
  )
  return group
end

local function count(entity, name, quality)
  return entity.get_item_count { name = name, quality = quality or "normal" }
end

local function power(target)
  local generator =
    target.create_entity { name = "electric-energy-interface", position = { -55, -55 }, force = "player" }
  generator.power_production = 1000000000000
  generator.electric_buffer_size = 1000000000000
  generator.energy = 1000000000000
  for x = -55, 55, 14 do
    for y = -55, 55, 14 do
      target.create_entity { name = "substation", position = { x, y }, force = "player" }
    end
  end
end

local function pair(item, amount, quality, options)
  local provider = chest("provider", storage.a)
  local requester = chest("requester", storage.b, options)
  provider.insert { name = item, count = amount, quality = quality or "normal" }
  local section = request(requester, item, amount, quality)
  return { provider = provider, requester = requester, section = section }
end

local function setup()
  game.speed = 1000
  storage.next_position = 0
  storage.a, storage.b, storage.c = surface "iln-source", surface "iln-destination", surface "iln-other"
  game.forces.player.research_all_technologies()
  for i = 1, 4 do
    game.forces.player.technologies["interplanetary-logistics-speed-" .. i].researched = false
  end
  game.create_force "iln-enemy"
  power(storage.a)
  power(storage.b)
  power(storage.c)
  local rocket = settings.startup["interplanetary-rocket-capacity"].value
  local weight = prototypes.item["interplanetary-provider-chest"].weight
  assert_equal(math.floor(1000000 / weight), rocket, "Rocket payload capacity")
  storage.batch = pair("stone-wall", 300)
  storage.outage_surface = surface "iln-unpowered"
  storage.outage_provider = chest("provider", storage.a)
  storage.outage_provider.insert { name = "electronic-circuit", count = 9 }
  storage.outage_requester = chest("requester", storage.outage_surface)
  request(storage.outage_requester, "electronic-circuit", 9)
  storage.robots_blocked = chest("requester", storage.b)
  request(storage.robots_blocked, "stone-brick", 20)
  storage.robots_allowed = chest("requester", storage.b, { allow_local = true })
  request(storage.robots_allowed, "stone-brick", 10)
  local local_source = build("passive-provider-chest", storage.b, { -30, -28 })
  local_source.insert { name = "stone-brick", count = 100 }
  storage.robot_buffer = chest("requester", storage.b, { allow_local = true })
  storage.robot_buffer.insert { name = "concrete", count = 10 }
  storage.robot_target = build("requester-chest", storage.b, { -30, -20 })
  storage.robot_target.request_from_buffers = true
  request(storage.robot_target, "concrete", 10)
  local roboport = build("roboport", storage.b, { -30, -35 })
  roboport.energy = 100000000
  roboport.get_inventory(defines.inventory.roboport_robot).insert { name = "logistic-robot", count = 50 }
  storage.circuit = pair("explosives", 6)
  local behavior = storage.circuit.requester.get_or_create_control_behavior()
  behavior.circuit_condition_enabled = true
  behavior.circuit_condition =
    { first_signal = { type = "virtual", name = "signal-A" }, comparator = ">", constant = 0 }
  storage.quality = pair("iron-plate", 7, "rare")
  storage.quality.provider.insert { name = "iron-plate", count = 11 }
  storage.multi = pair("copper-plate", 17)
  storage.multi.provider.insert { name = "steel-plate", count = 19 }
  request(storage.multi.requester, "steel-plate", 19)
  storage.partial = pair("stone", 13)
  storage.small = pair("coal", 5)
  local section = storage.small.section
  section.multiplier = 2
  storage.small.provider.insert { name = "coal", count = 5 }
  local disabled = request(storage.small.requester, "uranium-238", 3)
  disabled.active = false
  storage.small.provider.insert { name = "uranium-238", count = 3 }
  storage.shared = chest("provider", storage.a)
  storage.shared.insert { name = "uranium-235", count = 10 }
  storage.shared_requests = {}
  for i = 1, 2 do
    local entity = chest("requester", storage.b)
    request(entity, "uranium-235", 7)
    storage.shared_requests[i] = entity
  end
  storage.enemy_provider = chest("provider", storage.a, nil, "iln-enemy")
  storage.enemy_provider.insert { name = "copper-cable", count = 20 }
  storage.enemy_requester = chest("requester", storage.b)
  request(storage.enemy_requester, "copper-cable", 20)
  storage.local_provider = chest("provider", storage.b)
  storage.local_provider.insert { name = "iron-gear-wheel", count = 4 }
  storage.local_requester = chest("requester", storage.b)
  request(storage.local_requester, "iron-gear-wheel", 4)
  storage.cancelled = pair("plastic-bar", 10)
  storage.full = pair("sulfur", 10)
  storage.full.requester.get_inventory(defines.inventory.chest).set_bar(1)
  storage.routed = pair("processing-unit", 5, nil, { source_surface = "iln-other" })
  storage.routed_provider = chest("provider", storage.c)
  storage.routed_provider.insert { name = "processing-unit", count = 5 }
  storage.armor = pair("power-armor", 1, "epic")
  local armor = storage.armor.provider
    .get_inventory(defines.inventory.chest)
    .find_item_stack { name = "power-armor", quality = "epic" }
  armor.grid.put { name = "battery-equipment", position = { 0, 0 } }
  storage.blueprint = pair("blueprint", 1)
  local blueprint = storage.blueprint.provider.get_inventory(defines.inventory.chest).find_item_stack "blueprint"
  blueprint.label = "ILN metadata survives"
  blueprint.set_blueprint_entities { { entity_number = 1, name = "stone-furnace", position = { 0, 0 } } }
  storage.spoil = pair("agricultural-science-pack", 10)
  storage.spoil.provider
    .get_inventory(defines.inventory.chest)
    .find_item_stack("agricultural-science-pack").spoil_percent =
    0.4
  local original = chest("provider", storage.a)
  storage.cloned_source = original
  local pos = original.position
  original.surface.clone_area {
    source_area = { { pos.x - 2, pos.y - 2 }, { pos.x + 2, pos.y + 2 } },
    destination_area = { { 10, 30 }, { 14, 34 } },
    destination_surface = storage.c,
    clone_entities = true,
  }
  storage.area_clone =
    storage.c.find_entities_filtered({ name = "interplanetary-provider-chest", area = { { 10, 30 }, { 14, 34 } } })[1]
  assert(storage.area_clone, "Area clone placed")
  storage.cloned = original.clone { position = { 40, 40 }, surface = storage.c, force = "player" }
  storage.destroyed = pair("battery", 2)
  storage.destroy_position = storage.destroyed.requester.position
  storage.script_destroyed = chest("provider", storage.a)
  storage.script_destroy_position = storage.script_destroyed.position
  storage.platform = game.forces.player.create_space_platform {
    name = "ILN test platform",
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack",
  }
  assert(storage.platform, "Space platform creation")
  storage.platform.apply_starter_pack()
  log "ILN integration setup complete"
end

script.on_init(function()
  game.speed = 1000
end)

script.on_event(defines.events.on_tick, function(event)
  if event.tick > 30 and storage.platform and not storage.platform_requester then
    local entity = storage.platform.surface.find_entity("interplanetary-requester-chest", { 8.5, 8.5 })
    if entity then
      storage.platform_requester = entity
      request(entity, "advanced-circuit", 8)
    end
  end
  if event.tick == 1 then
    setup()
  elseif event.tick == 30 then
    assert_equal(count(storage.partial.requester, "stone"), 0, "Duration applies even with free power")
    -- Simulate request edits and deletion while energy is being charged.
    storage.cancelled.section.active = false
    storage.destroyed.requester.destroy { raise_destroy = true }
    storage.script_destroyed.destroy()
    local target = storage.platform.surface
    local tiles = {}
    for x = -20, 20 do
      for y = -20, 20 do
        tiles[#tiles + 1] = { name = "space-platform-foundation", position = { x, y } }
      end
    end
    target.set_tiles(tiles)
    storage.platform_provider = build("interplanetary-provider-chest", storage.a, { 40, 30 })
    storage.platform_provider.insert { name = "advanced-circuit", count = 8 }
    storage.platform.surface.create_entity {
      name = "entity-ghost",
      inner_name = "interplanetary-requester-chest",
      position = { 8, 8 },
      force = "player",
    }
    storage.platform.hub.insert { name = "interplanetary-requester-chest", count = 1 }

    local generator =
      target.create_entity { name = "electric-energy-interface", position = { 12, 8 }, force = "player" }
    generator.power_production = 1000000000000
    generator.electric_buffer_size = 1000000000000
    generator.energy = 1000000000000
    target.create_entity { name = "substation", position = { 10, 5 }, force = "player" }
  elseif event.tick == 1200 then
    if settings.startup["interplanetary-power-cost"].value ~= "free" then
      assert_equal(count(storage.outage_requester, "electronic-circuit"), 0, "Wait for destination power")
      assert_equal(count(storage.outage_provider, "electronic-circuit"), 9, "Outage retains source items")
    end
    power(storage.outage_surface)
  elseif event.tick == 3600 then
    assert_equal(count(storage.outage_requester, "electronic-circuit"), 9, "Resume after power restored")
    assert_equal(count(storage.robots_blocked, "stone-brick"), 0, "No local robot delivery loop")
    assert(count(storage.robots_allowed, "stone-brick") >= 10, "Opt-in local robot deliveries")
    assert_equal(count(storage.robot_target, "concrete"), 10, "Robots collect from ILN buffer")
    assert_equal(count(storage.circuit.requester, "explosives"), 0, "Circuit disable condition")
    assert_equal(count(storage.batch.requester, "stone-wall"), 300, "Configurable batch throughput")
    assert_equal(count(storage.quality.requester, "iron-plate", "rare"), 7, "Quality request")
    assert_equal(count(storage.quality.requester, "iron-plate"), 0, "No quality substitution")
    assert_equal(count(storage.quality.provider, "iron-plate"), 11, "Normal stock retained")
    assert_equal(count(storage.multi.requester, "copper-plate"), 17, "Simultaneous first item")
    assert_equal(count(storage.multi.requester, "steel-plate"), 19, "Simultaneous second item")
    assert_equal(count(storage.partial.requester, "stone"), 13, "Partial stack")
    assert_equal(count(storage.small.requester, "coal"), 10, "Section multiplier")
    assert_equal(count(storage.small.requester, "uranium-238"), 0, "Disabled section")
    assert_equal(
      count(storage.shared_requests[1], "uranium-235") + count(storage.shared_requests[2], "uranium-235"),
      10,
      "Shared provider conservation"
    )
    assert_equal(count(storage.enemy_requester, "copper-cable"), 0, "Force isolation")
    assert_equal(count(storage.local_requester, "iron-gear-wheel"), 0, "Different-surface routing")
    assert_equal(count(storage.cancelled.requester, "plastic-bar"), 0, "Cancel edited request")
    assert_equal(count(storage.cancelled.provider, "plastic-bar"), 10, "Cancellation retains items")
    assert_equal(count(storage.full.requester, "sulfur"), 0, "Inventory bar")
    assert_equal(count(storage.full.provider, "sulfur"), 10, "Full destination retains items")
    assert_equal(count(storage.routed.requester, "processing-unit"), 5, "Selected source")
    assert_equal(count(storage.routed.provider, "processing-unit"), 5, "Other source untouched")
    assert_equal(count(storage.armor.requester, "power-armor", "epic"), 1, "Equipment item quality")
    local armor = storage.armor.requester
      .get_inventory(defines.inventory.chest)
      .find_item_stack { name = "power-armor", quality = "epic" }
    assert_equal(#armor.grid.equipment, 1, "Equipment preserved")
    local blueprint = storage.blueprint.requester.get_inventory(defines.inventory.chest).find_item_stack "blueprint"
    assert(blueprint, "Blueprint delivered")
    assert_equal(blueprint.label, "ILN metadata survives", "Blueprint label preserved")
    assert_equal(#blueprint.get_blueprint_entities(), 1, "Blueprint entities preserved")
    local spoil =
      storage.spoil.requester.get_inventory(defines.inventory.chest).find_item_stack "agricultural-science-pack"
    assert(spoil and spoil.spoil_percent >= 0.4, "Spoilage preserved")
    for _, entity in ipairs { storage.cloned_source, storage.cloned, storage.area_clone } do
      assert_equal(
        entity.surface.count_entities_filtered {
          name = "interplanetary-provider-animation-idle",
          position = entity.position,
          radius = 0.1,
        },
        1,
        "Clone animations"
      )
    end
    assert_equal(
      storage.b.count_entities_filtered {
        type = "simple-entity-with-force",
        position = storage.destroy_position,
        radius = 1,
      },
      0,
      "Destroyed chest animation cleanup"
    )
    assert_equal(
      storage.a.count_entities_filtered {
        type = "simple-entity-with-force",
        position = storage.script_destroy_position,
        radius = 1,
      },
      0,
      "Unraised destruction cleanup"
    )
    assert(
      storage.b.can_place_entity {
        name = "interplanetary-requester-chest",
        position = storage.destroy_position,
        force = "player",
      },
      "Can rebuild after removal"
    )
    assert_equal(count(storage.platform_requester, "advanced-circuit"), 8, "Planet-to-platform transfer")
    local point = storage.quality.requester.get_logistic_point(defines.logistic_member_index.logistic_container)
    assert_equal(point.enabled, false, "Local robot deliveries default off")
    assert(
      storage.quality.provider.get_wire_connector(defines.wire_connector_id.circuit_red, true),
      "Provider circuit connector"
    )
    assert(
      storage.quality.requester.get_wire_connector(defines.wire_connector_id.circuit_green, true),
      "Requester circuit connector"
    )
    local stats = storage.c.find_entities_filtered({ type = "electric-pole" })[1].electric_network_statistics
    local energy = stats.get_input_count "interplanetary-provider-power-interface"
      + stats.get_output_count "interplanetary-provider-power-interface"
    local base = ({ free = 0, normal = 64000000, extreme = 320000000 })[settings.startup["interplanetary-power-cost"].value]
    local multiplier = ({ ["ultra-slow"] = 0.625, slow = 0.75, normal = 1, fast = 2, ["ultra-fast"] = 5 })[settings.startup["interplanetary-transfer-speed"].value]
    local expected = base * multiplier * 5 / prototypes.item["processing-unit"].stack_size
    assert(
      math.abs(energy - expected) < math.max(1, expected * 0.000001),
      "Metered sending energy: expected " .. expected .. ", got " .. energy
    )
    log("ILN metered energy: " .. energy .. " J; expected " .. expected .. " J")
    log "ILN INTEGRATION PASS: quality, partial stacks, concurrent requests, reservations, forces, routes, sections, metadata, platforms, cleanup, circuits"
  end
end)
