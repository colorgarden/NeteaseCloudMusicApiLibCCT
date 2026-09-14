-- 电台详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    time = js.or_(query.time, "-1"),
    id = query.id,
    limit = js.or_(query.limit, "20"),
    total = "true",
  }
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/djradio/subscriber", data, createOption(query, "weapi"))
end
