-- Data stage for Interplanetary Logistics Network
-- Prototype definitions for interplanetary logistics chests

-- Custom graphics integrated into chest entities

data:extend({
  -- Interplanetary Provider Chest (Container)
  {
    type = "logistic-container",
    logistic_mode = "passive-provider",
    name = "interplanetary-provider-chest",
    icon = "__interplanetary-logistics-network__/graphics/entities/provider_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "interplanetary-provider-chest"},
    max_health = 350,
    corpse = "passive-provider-chest-remnants",
    dying_explosion = "passive-provider-chest-explosion",
    collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    resistances = {
      {
        type = "fire",
        percent = 90
      },
      {
        type = "impact",
        percent = 60
      }
    },
    fast_replaceable_group = "container",
    icon_draw_specification = {scale = 0.7},
    open_sound = {filename = "__base__/sound/metallic-chest-open.ogg"},
    close_sound = {filename = "__base__/sound/metallic-chest-close.ogg"},
    impact_category = "metal",
    inventory_size = 48,
    picture = {
      layers = {
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/provider_animation_sheet_idle.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 1,
          line_length = 1,
          shift = {0, 0.1},
          scale = 0.625,
          tint = {r=0.5, g=0.5, b=0.5, a=0.3}
        }
      }
    }
  },

  -- Interplanetary Provider Animation Machine (Idle)
  {
    type = "simple-entity-with-force",
    name = "interplanetary-provider-animation-idle",
    icon = "__interplanetary-logistics-network__/graphics/entities/provider_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map", "not-deconstructable"},
    max_health = 1,
    collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
    selection_box = {{0, 0}, {0, 0}},
    collision_mask = {layers = {}},
    animations = {
      layers = {
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/provider_animation_sheet_idle.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.2,
          render_layer = "selection-box"
        },
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/provider_emission_sheet_idle.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.3,
          blend_mode = "additive",
          draw_as_glow = true,
          tint = {r=100.0, g=40.0, b=40.0, a=0.7},
          render_layer = "selection-box"
        }
      }
    }
  },

  -- Interplanetary Provider Animation Machine (Active)
  {
    type = "simple-entity-with-force",
    name = "interplanetary-provider-animation-active",
    icon = "__interplanetary-logistics-network__/graphics/entities/provider_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map", "not-deconstructable"},
    max_health = 1,
    collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
    selection_box = {{0, 0}, {0, 0}},
    collision_mask = {layers = {}},
    animations = {
      layers = {
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/provider_animation_sheet_active.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.5,
          render_layer = "selection-box"
        },
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/provider_emission_sheet_active.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.7,
          blend_mode = "additive",
          draw_as_glow = true,
          tint = {r=200.0, g=80.0, b=80.0, a=1.0},
          render_layer = "selection-box"
        }
      }
    }
  },


  -- Interplanetary Requester Chest (Container)
  {
    type = "logistic-container",
    logistic_mode = "requester",
    name = "interplanetary-requester-chest",
    icon = "__interplanetary-logistics-network__/graphics/entities/requester_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-player", "player-creation"},
    minable = {mining_time = 0.1, result = "interplanetary-requester-chest"},
    max_health = 350,
    corpse = "requester-chest-remnants",
    dying_explosion = "requester-chest-explosion",
    collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    resistances = {
      {
        type = "fire",
        percent = 90
      },
      {
        type = "impact",
        percent = 60
      }
    },
    fast_replaceable_group = "container",
    icon_draw_specification = {scale = 0.7},
    open_sound = {filename = "__base__/sound/metallic-chest-open.ogg"},
    close_sound = {filename = "__base__/sound/metallic-chest-close.ogg"},
    impact_category = "metal",
    inventory_size = 48,
    picture = {
      layers = {
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/requester_animation_sheet_idle.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 1,
          line_length = 1,
          shift = {0, 0.1},
          scale = 0.625,
          tint = {r=0.5, g=0.5, b=0.5, a=0.3}
        }
      }
    }
  },

  -- Interplanetary Requester Animation Machine (Idle)
  {
    type = "simple-entity-with-force",
    name = "interplanetary-requester-animation-idle",
    icon = "__interplanetary-logistics-network__/graphics/entities/requester_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map", "not-deconstructable"},
    max_health = 1,
    collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
    selection_box = {{0, 0}, {0, 0}},
    collision_mask = {layers = {}},
    animations = {
      layers = {
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/requester_animation_sheet_idle.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.2,
          render_layer = "selection-box"
        },
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/requester_emission_sheet_idle.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.3,
          blend_mode = "additive",
          draw_as_glow = true,
          tint = {r=40.0, g=100.0, b=40.0, a=0.7},
          render_layer = "selection-box"
        }
      }
    }
  },

  -- Interplanetary Requester Animation Machine (Active)
  {
    type = "simple-entity-with-force",
    name = "interplanetary-requester-animation-active",
    icon = "__interplanetary-logistics-network__/graphics/entities/requester_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map", "not-deconstructable"},
    max_health = 1,
    collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
    selection_box = {{0, 0}, {0, 0}},
    collision_mask = {layers = {}},
    animations = {
      layers = {
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/requester_animation_sheet_active.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.5,
          render_layer = "selection-box"
        },
        {
          filename = "__interplanetary-logistics-network__/graphics/entities/requester_emission_sheet_active.png",
          priority = "extra-high",
          width = 192,
          height = 192,
          frame_count = 8,
          line_length = 8,
          shift = {0, 0.1},
          scale = 0.625,
          animation_speed = 0.7,
          blend_mode = "additive",
          draw_as_glow = true,
          tint = {r=80.0, g=200.0, b=80.0, a=1.0},
          render_layer = "selection-box"
        }
      }
    }
  },


  -- Items for the chests
  {
    type = "item",
    name = "interplanetary-provider-chest",
    icon = "__interplanetary-logistics-network__/graphics/entities/provider_idle_icon.png",
    icon_size = 64,
    subgroup = "logistic-network",
    order = "b[storage]-c[interplanetary-provider-chest]",
    place_result = "interplanetary-provider-chest",
    stack_size = 50
  },

  {
    type = "item",
    name = "interplanetary-requester-chest",
    icon = "__interplanetary-logistics-network__/graphics/entities/requester_idle_icon.png",
    icon_size = 64,
    subgroup = "logistic-network",
    order = "b[storage]-d[interplanetary-requester-chest]",
    place_result = "interplanetary-requester-chest",
    stack_size = 50
  },


  -- Basic recipes (will need technology later)
  {
    type = "recipe",
    name = "interplanetary-provider-chest",
    enabled = true,
    ingredients = {
      {type = "item", name = "passive-provider-chest", amount = 1},
      {type = "item", name = "processing-unit", amount = 5},
      {type = "item", name = "steel-plate", amount = 10}
    },
    results = {{type = "item", name = "interplanetary-provider-chest", amount = 1}}
  },

  {
    type = "recipe",
    name = "interplanetary-requester-chest",
    enabled = true,
    ingredients = {
      {type = "item", name = "requester-chest", amount = 1},
      {type = "item", name = "processing-unit", amount = 5},
      {type = "item", name = "steel-plate", amount = 10}
    },
    results = {{type = "item", name = "interplanetary-requester-chest", amount = 1}}
  },

  -- Simplified hidden roboport for interplanetary network (copy base roboport and modify)
  {
    type = "roboport",
    name = "interplanetary-roboport",
    icon = "__base__/graphics/icons/roboport.png",
    flags = {"not-on-map"},
    max_health = 1,
    corpse = "big-remnants",
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{-0.1, -0.1}, {0.1, 0.1}},
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      input_flow_limit = "1MW"
    },
    recharge_minimum = "40MJ",
    energy_usage = "50kW",
    charging_energy = "1000kW",
    logistics_radius = 999999,
    construction_radius = 0,
    charge_approach_distance = 2.6,
    robot_slots_count = 0,
    material_slots_count = 0,
    stationing_offset = {0, 0},
    charging_offsets = {{-1.5, -0.5}, {1.5, -0.5}, {1.5, 1.5}, {-1.5, 1.5}},
    logistics_connection_distance = 999999,
    request_to_open_door_timeout = 15,
    spawn_and_station_height = -0.1,
    spawn_and_station_shadow_height_offset = 0,
    draw_logistic_radius_visualization = false,
    draw_construction_radius_visualization = false,
    base_patch = {
      filename = "__base__/graphics/entity/roboport/roboport-base.png",
      priority = "medium",
      width = 143,
      height = 135,
      shift = {0.5, 0.25},
      scale = 0.1
    },
    base_animation = {
      filename = "__base__/graphics/entity/roboport/roboport-base-animation.png",
      priority = "medium",
      width = 42,
      height = 31,
      frame_count = 8,
      animation_speed = 0.5,
      shift = {-1.5, -2.625},
      scale = 0.1
    },
    door_animation_up = {
      filename = "__base__/graphics/entity/roboport/roboport-door-up.png",
      priority = "medium",
      width = 52,
      height = 20,
      frame_count = 16,
      shift = {0.015625, -0.890625},
      scale = 0.1
    },
    door_animation_down = {
      filename = "__base__/graphics/entity/roboport/roboport-door-down.png",
      priority = "medium",
      width = 52,
      height = 22,
      frame_count = 16,
      shift = {0.015625, -0.234375},
      scale = 0.1
    },
    recharging_animation = {
      filename = "__base__/graphics/entity/roboport/roboport-recharging.png",
      priority = "high",
      width = 37,
      height = 35,
      frame_count = 16,
      scale = 0.1,
      animation_speed = 0.5
    }
  },


  -- Provider power interface for transfers
  {
    type = "electric-energy-interface",
    name = "interplanetary-provider-power-interface",
    icon = "__interplanetary-logistics-network__/graphics/entities/provider_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map"},
    max_health = 1,
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{0, 0}, {0, 0}},
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      input_flow_limit = "10MW",
      buffer_capacity = "10MJ"
    },
    energy_usage = "0W",
    energy_production = "0W",
    energy_consumption = "0W",
    picture = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1
    }
  },

  -- Requester power interface for transfers
  {
    type = "electric-energy-interface",
    name = "interplanetary-requester-power-interface",
    icon = "__interplanetary-logistics-network__/graphics/entities/requester_idle_icon.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map"},
    max_health = 1,
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selection_box = {{0, 0}, {0, 0}},
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      input_flow_limit = "10MW",
      buffer_capacity = "10MJ"
    },
    energy_usage = "0W",
    energy_production = "0W",
    energy_consumption = "0W",
    picture = {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1
    }
  },

  -- Technology to unlock interplanetary logistics
  {
    type = "technology",
    name = "interplanetary-logistics",
    icon = "__base__/graphics/technology/logistic-system.png",
    icon_size = 256,
    effects = {
      {
        type = "unlock-recipe",
        recipe = "interplanetary-provider-chest"
      },
      {
        type = "unlock-recipe",
        recipe = "interplanetary-requester-chest"
      }
    },
    prerequisites = {"logistic-system"},
    unit = {
      count = 500,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 60
    },
    order = "c-k-f"
  },

  -- Interplanetary Logistics Speed 1 (requires Fulgora)
  {
    type = "technology",
    name = "interplanetary-logistics-speed-1",
    icon = "__base__/graphics/technology/logistic-system.png",
    icon_size = 256,
    effects = {},
    prerequisites = {"interplanetary-logistics", "electromagnetic-science-pack"},
    unit = {
      count = 1000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
        {"electromagnetic-science-pack", 1}
      },
      time = 60
    },
    order = "c-k-f-a"
  },

  -- Interplanetary Logistics Speed 2 (requires Gleba)
  {
    type = "technology",
    name = "interplanetary-logistics-speed-2",
    icon = "__base__/graphics/technology/logistic-system.png",
    icon_size = 256,
    effects = {},
    prerequisites = {"interplanetary-logistics-speed-1", "agricultural-science-pack"},
    unit = {
      count = 1500,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 60
    },
    order = "c-k-f-b"
  },

  -- Interplanetary Logistics Speed 3 (requires Aquilo)
  {
    type = "technology",
    name = "interplanetary-logistics-speed-3",
    icon = "__base__/graphics/technology/logistic-system.png",
    icon_size = 256,
    effects = {},
    prerequisites = {"interplanetary-logistics-speed-2", "cryogenic-science-pack"},
    unit = {
      count = 2000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"cryogenic-science-pack", 1}
      },
      time = 60
    },
    order = "c-k-f-c"
  },

  -- Interplanetary Logistics Speed 4 (requires Promethium)
  {
    type = "technology",
    name = "interplanetary-logistics-speed-4",
    icon = "__base__/graphics/technology/logistic-system.png",
    icon_size = 256,
    effects = {},
    prerequisites = {"interplanetary-logistics-speed-3", "promethium-science-pack"},
    unit = {
      count = 5000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"promethium-science-pack", 1}
      },
      time = 60
    },
    order = "c-k-f-d"
  }
})
