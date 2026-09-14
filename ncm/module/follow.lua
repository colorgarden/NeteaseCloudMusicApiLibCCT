-- 关注与取消关注用户

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(tonumber(query.t) == 1, "follow", "delfollow")
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/user/" .. js.tostr(query.t) .. "/" .. js.tostr(query.id),
    {},
    createOption(query, "weapi")
  )
end
