data:extend({
  {
    type = "string-setting",
    name = "interplanetary-power-cost",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"free", "cheap", "normal", "expensive", "extreme"},
    order = "a"
  },
  {
    type = "string-setting",
    name = "interplanetary-transfer-speed",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"ultra-slow", "slow", "normal", "fast", "ultra-fast"},
    order = "b"
  },
  {
    type = "int-setting",
    name = "interplanetary-rocket-capacity",
    setting_type = "startup",
    default_value = 0,
    allowed_values = {0, 1, 2, 3, 5, 10},
    order = "c"
  }
})
