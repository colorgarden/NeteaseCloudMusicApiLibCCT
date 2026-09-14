-- 一起听 房间情况

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    roomId = query.roomId,
  }
  return request("/api/listen/together/room/check", data, createOption(query))
end
