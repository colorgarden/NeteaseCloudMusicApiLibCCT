-- 一起听 结束房间

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    roomId = query.roomId,
  }
  return request("/api/listen/together/end/v2", data, createOption(query))
end
