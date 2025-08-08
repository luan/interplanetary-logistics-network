local M = {}

function M.init()
  storage.interplanetary_chests = storage.interplanetary_chests or {}
  storage.transfer_cooldowns = storage.transfer_cooldowns or {}
  storage.pending_transfers = storage.pending_transfers or {}
  storage.active_emissions = storage.active_emissions or {}
  storage.emission_timers = storage.emission_timers or {}
  storage.active_transfers = storage.active_transfers or {}
  storage.power_failure_notifications = storage.power_failure_notifications or {}
  storage.power_failure_counts = storage.power_failure_counts or {}
  storage.item_reservations = storage.item_reservations or {}
  storage.reservations_by_transfer = storage.reservations_by_transfer or {}
end

return M
