-- 转发动态

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    forwards = query.forwards,
    id = query.evId,
    eventUserId = query.uid,
  }
  return request("/api/event/forward", data, createOption(query))
end
