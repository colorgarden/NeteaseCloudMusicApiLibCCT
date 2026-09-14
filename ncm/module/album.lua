-- 专辑内容

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/v1/album/" .. js.tostr(query.id), {}, createOption(query, "weapi"))
end
