-- 私信内容

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    userId = query.uid,
    limit = js.or_(query.limit, 30),
    time = js.or_(query.before, 0),
    total = "true",
  }
  return request("/api/msg/private/history", data, createOption(query, "weapi"))
end
