-- 用户动态

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    getcounts = true,
    time = js.or_(query.lasttime, -1),
    limit = js.or_(query.limit, 30),
    total = false,
  }
  return request("/api/event/get/" .. js.tostr(query.uid), data, createOption(query))
end
