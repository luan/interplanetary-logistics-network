data:extend({
  {
    type = "int-setting",
    name = "interplanetary-receiving-power",
    setting_type = "startup",
    default_value = 4000,
    minimum_value = 0,
    maximum_value = 50000,
    order = "a"
  },
  {
    type = "int-setting",
    name = "interplanetary-sending-power",
    setting_type = "startup",
    default_value = 16000,
    minimum_value = 0,
    maximum_value = 50000,
    order = "b"
  },
  {
    type = "string-setting",
    name = "interplanetary-transfer-speed",
    setting_type = "startup",
    default_value = "normal",
    allowed_values = {"ultra-slow", "slow", "normal", "fast", "ultra-fast"},
    order = "c"
  }
})
