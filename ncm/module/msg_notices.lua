-- 通知

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 30),
    time = js.or_(query.lasttime, -1),
  }
  return request("/api/msg/notices", data, createOption(query, "weapi"))
end
