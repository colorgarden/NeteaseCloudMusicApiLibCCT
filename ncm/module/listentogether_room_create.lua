-- 一起听创建房间

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    refer = "songplay_more",
  }
  return request("/api/listen/together/room/create", data, createOption(query))
end
