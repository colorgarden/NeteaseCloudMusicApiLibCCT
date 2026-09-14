-- 获取动态列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    pagesize = js.or_(query.pagesize, 20),
    lasttime = js.or_(query.lasttime, -1),
  }
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/v1/event/get", data, createOption(query, "weapi"))
end
