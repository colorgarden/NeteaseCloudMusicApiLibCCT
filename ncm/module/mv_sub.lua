-- 收藏与取消收藏MV

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(tonumber(query.t) == 1, "sub", "unsub")
  local data = {
    mvId = query.mvid,
    mvIds = '["' .. js.tostr(query.mvid) .. '"]',
  }
  return request("/api/mv/" .. query.t, data, createOption(query, "weapi"))
end
