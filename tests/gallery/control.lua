-- A real single-player showcase world using the unmodified released mod.
local function build(surface, name, x, y, direction, options)
  if options then
    local ghost = assert(surface.create_entity {
      name = "entity-ghost",
      inner_name = name,
      position = { x, y },
      force = "player",
      tags = { iln = options },
    })
    local _, entity = ghost.revive { raise_revive = true }
    return assert(entity, name)
  end
  return assert(
    surface.create_entity {
      name = name,
      position = { x, y },
      direction = direction,
      force = "player",
      raise_built = true,
    },
    name
  )
end

local function prepare(surface)
  surface.request_to_generate_chunks({ 0, 0 }, 3)
  surface.force_generate_chunk_requests()
  for _, entity in pairs(surface.find_entities_filtered { area = { { -25, -20 }, { 25, 20 } } }) do
    if entity.type ~= "character" then
      entity.destroy()
    end
  end
  surface.destroy_decoratives { area = { { -25, -20 }, { 25, 20 } } }
  local tiles = {}
  for x = -18, 17 do
    for y = -12, 11 do
      local tile = "refined-concrete"
      if y == -10 or y == 9 then
        tile = "refined-hazard-concrete-left"
      end
      tiles[#tiles + 1] = { name = tile, position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  surface.freeze_daytime = true
  surface.daytime = 0
  local power = build(surface, "electric-energy-interface", 0.5, -17.5)
  power.power_production = 1000000000
  power.electric_buffer_size = 1000000000
  power.energy = 1000000000
  for _, y in ipairs { -15.5, -7.5, 7.5 } do
    build(surface, "substation", 0.5, y)
  end
end

local function request(entity, name, amount)
  local section = entity.get_logistic_sections().add_section()
  section.set_slot(1, { value = { name = name, quality = "normal", comparator = "=" }, min = amount })
end

script.on_init(function()
  local force = game.forces.player
  force.research_all_technologies()
  for i = 1, 4 do
    force.technologies["interplanetary-logistics-speed-" .. i].researched = false
  end
  game.map_settings.enemy_expansion.enabled = false
  game.map_settings.pollution.enabled = false
  local main = game.surfaces.nauvis
  local remote_surface = game.planets.vulcanus.create_surface()
  prepare(main)
  prepare(remote_surface)
  storage.provider = build(main, "interplanetary-provider-chest", -5.5, -0.5)
  storage.provider.insert { name = "iron-plate", count = 3000 }
  storage.remote_provider = build(remote_surface, "interplanetary-provider-chest", -5.5, -0.5)
  storage.remote_provider.insert { name = "electronic-circuit", count = 3000 }
  storage.requester = build(
    main,
    "interplanetary-requester-chest",
    5.5,
    -0.5,
    nil,
    { source_surface = "vulcanus", source_provider = storage.remote_provider.unit_number }
  )
  request(storage.requester, "electronic-circuit", 1000)
  storage.remote_requester = build(
    remote_surface,
    "interplanetary-requester-chest",
    5.5,
    -0.5,
    nil,
    { source_surface = "nauvis", source_provider = storage.provider.unit_number }
  )
  request(storage.remote_requester, "iron-plate", 2000)
  for y = -7, 7 do
    build(main, "express-transport-belt", -8.5, y + 0.5, defines.direction.south)
    build(main, "express-transport-belt", 8.5, y + 0.5, defines.direction.south)
  end
  for _, x in ipairs { -11.5, -7.5 } do
    build(main, "medium-electric-pole", x, -6.5)
  end
  for _, x in ipairs { 7.5, 11.5 } do
    build(main, "medium-electric-pole", x, 7.5)
  end
  local stock = build(main, "steel-chest", -10.5, -5.5)
  stock.insert { name = "iron-plate", count = 4800 }
  build(main, "fast-inserter", -9.5, -5.5, defines.direction.west)
  build(main, "fast-inserter", -7.5, -0.5, defines.direction.west)
  build(main, "fast-inserter", 7.5, -0.5, defines.direction.west)
  build(main, "steel-chest", 10.5, 7.5)
  build(main, "fast-inserter", 9.5, 7.5, defines.direction.west)
  local gears = build(main, "assembling-machine-3", -5.5, 5.5)
  gears.set_recipe "iron-gear-wheel"
  gears.insert { name = "iron-plate", count = 400 }
  build(main, "fast-inserter", -7.5, 5.5, defines.direction.west)
  build(main, "fast-inserter", -3.5, 5.5, defines.direction.west)
  for x = -2, 1 do
    build(main, "express-transport-belt", x + 0.5, 5.5, defines.direction.east)
  end
  build(main, "steel-chest", 2.5, 5.5)
  local circuits = build(main, "assembling-machine-3", 5.5, 5.5)
  circuits.set_recipe "advanced-circuit"
  circuits.insert { name = "plastic-bar", count = 400 }
  circuits.insert { name = "copper-cable", count = 800 }
  build(main, "fast-inserter", 7.5, 5.5, defines.direction.east)
  build(main, "fast-inserter", 3.5, 5.5, defines.direction.east)
  force.chart(main, { { -32, -24 }, { 32, 24 } })
  storage.captures = {}
  log("ILN GALLERY WORLD READY; released mod " .. script.active_mods["interplanetary-logistics-network"])
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  player.set_controller { type = defines.controllers.god }
  player.teleport({ 0, 0 }, game.surfaces.nauvis)
  player.zoom = 1.4
end)

local function capture(name, zoom, position, gui)
  local player = game.get_player(1)
  game.take_screenshot {
    player = player,
    surface = "nauvis",
    position = position,
    resolution = gui and { 3200, 2000 } or { 1600, 1000 },
    zoom = zoom,
    path = "gallery/" .. name .. ".png",
    show_gui = gui,
    show_entity_info = name == "01-machines",
    anti_alias = not gui,
    hide_clouds = true,
    hide_fog = true,
    hide_health_bars = true,
  }
  game.set_wait_for_screenshots_to_finish()
  storage.captures[name] = {
    tick = game.tick,
    zoom = zoom,
    show_gui = gui,
    requester_circuits = storage.requester.get_item_count "electronic-circuit",
    remote_received_iron = storage.remote_requester.get_item_count "iron-plate",
    active_animation_helpers = #game.surfaces.nauvis.find_entities_filtered {
      name = { "interplanetary-provider-animation-active", "interplanetary-requester-animation-active" },
    },
  }
  helpers.write_file(
    "gallery/receipt.json",
    helpers.table_to_json {
      factorio = script.active_mods.base,
      mod = script.active_mods["interplanetary-logistics-network"],
      provenance = "Unedited screenshots written by the graphical Factorio client using game.take_screenshot",
      captures = storage.captures,
    },
    false
  )
  log("ILN GALLERY CAPTURE " .. name)
end

script.on_nth_tick(15, function()
  local player = game.get_player(1)
  if not player or not player.connected then
    return
  end
  if game.tick >= 600 and not storage.captures["01-machines"] then
    capture("01-machines", 1.4, { 0, 0 }, false)
  elseif game.tick >= 660 and not storage.captures["02-provider"] then
    capture("02-provider", 2.1, { 0, -0.5 }, false)
  elseif game.tick >= 720 and not storage.open_requested then
    player.opened = storage.requester
    storage.open_requested = true
    log "ILN GALLERY REQUESTER OPENED"
  elseif game.tick >= 780 and player.gui.relative.iln_requester and not storage.captures["03-requester"] then
    capture("03-requester", 1.5, { -1, 0 }, true)
    log "ILN GALLERY CAPTURES COMPLETE"
  elseif game.tick >= 960 and storage.captures["03-requester"] and not storage.saved then
    storage.saved = true
    game.auto_save "iln-gallery"
  end
end)
