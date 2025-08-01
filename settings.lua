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
  }
})
