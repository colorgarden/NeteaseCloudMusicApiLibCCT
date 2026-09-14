-- 订阅与取消电台

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(tonumber(query.t) == 1, "sub", "unsub")
  local data = {
    id = query.rid,
  }
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/djradio/" .. js.tostr(query.t), data, createOption(query, "weapi"))
end
