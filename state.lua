local M = {}

function M.init()
  storage.interplanetary_chests = storage.interplanetary_chests or {}
  storage.pending_transfers = storage.pending_transfers or {}
  storage.item_reservations = storage.item_reservations or {}
  storage.destroyed_chests = storage.destroyed_chests or {}
  storage.next_transfer_id = storage.next_transfer_id or 0
end

return M
