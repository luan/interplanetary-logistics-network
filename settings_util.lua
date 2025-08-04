local M = {}

local cached = nil

local speed_configs = {
  ["ultra-slow"] = { duration = 16 * 60, power_multiplier = 0.625 },
  slow = { duration = 8 * 60, power_multiplier = 0.75 },
  normal = { duration = 4 * 60, power_multiplier = 1.0 },
  fast = { duration = 2 * 60, power_multiplier = 2.0 },
  ["ultra-fast"] = { duration = 1 * 60, power_multiplier = 5.0 },
}

local power_configs = {
  free = { sending = 0, receiving = 0 },
  cheap = { sending = 4000, receiving = 1000 },
  normal = { sending = 16000, receiving = 4000 },
  expensive = { sending = 40000, receiving = 10000 },
  extreme = { sending = 80000, receiving = 20000 },
}

local function compute()
  local speed_setting = settings.startup["interplanetary-transfer-speed"].value
  local power_setting = settings.startup["interplanetary-power-cost"].value
  local s = speed_configs[speed_setting] or speed_configs.normal
  local p = power_configs[power_setting] or power_configs.normal
  return {
    receiving_power = p.receiving * 1000 * s.power_multiplier,
    sending_power = p.sending * 1000 * s.power_multiplier,
    transfer_duration = s.duration,
  }
end

function M.get()
  cached = cached or compute()
  return cached
end

function M.invalidate()
  cached = nil
end

return M
