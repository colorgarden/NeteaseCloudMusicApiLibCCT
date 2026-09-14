-- 广播电台 - 收藏/取消收藏电台

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(js.tonum(query.t) == 1, "false", "true")
  local data = {
    contentType = "BROADCAST",
    contentId = query.id,
    cancelCollect = query.t,
  }
  return request("/api/content/interact/collect", data, createOption(query))
end
