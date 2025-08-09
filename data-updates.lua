-- Data-updates stage for Interplanetary Logistics Network
-- Apply rocket cargo compatibility based on settings

local rocket_capacity = settings.startup["interplanetary-rocket-capacity"].value

if rocket_capacity and rocket_capacity > 0 then
  -- Add rocket cargo weight to both chest types
  local weight = rocket_capacity
  
  -- Update provider chest
  local provider_item = data.raw.item["interplanetary-provider-chest"]
  if provider_item then
    provider_item.weight = weight
    provider_item.send_to_orbit_mode = "automated"
  end
  
  -- Update requester chest
  local requester_item = data.raw.item["interplanetary-requester-chest"]
  if requester_item then
    requester_item.weight = weight
    requester_item.send_to_orbit_mode = "automated"
  end
end