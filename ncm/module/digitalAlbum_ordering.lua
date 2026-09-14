-- 购买数字专辑

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  -- Account for JSON.stringify([{ business, resourceID, quantity }]) semantics:
  -- keys are emitted in declaration order and `undefined` values are omitted.
  local resource = '{"business":"Album"'
  if query.id ~= nil then
    resource = resource .. ',"resourceID":' .. json.encode(query.id)
  end
  if query.quantity ~= nil then
    resource = resource .. ',"quantity":' .. json.encode(query.quantity)
  end
  resource = resource .. "}"

  local data = {
    business = "Album",
    paymentMethod = query.payment,
    digitalResources = "[" .. resource .. "]",
    from = "web",
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request(
    "/api/ordering/web/digital",
    data,
    createOption(query, "weapi")
  )
end
