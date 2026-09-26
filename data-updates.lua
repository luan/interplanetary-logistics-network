-- Rocket payload is 1,000 kg; item weight is expressed in grams.
local capacity = settings.startup["interplanetary-rocket-capacity"].value
for _, name in ipairs { "interplanetary-provider-chest", "interplanetary-requester-chest" } do
  local item = data.raw.item[name]
  item.weight = capacity > 0 and math.floor(1000000 / capacity) or 1000001
  item.send_to_orbit_mode = "automated"
end
