-- 收藏/取消收藏专辑

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(tonumber(query.t) == 1, "sub", "unsub")
  local data = {
    id = query.id,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/album/" .. js.tostr(query.t), data, createOption(query, "weapi"))
end
