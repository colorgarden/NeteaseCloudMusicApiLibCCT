-- 一起听 当前列表获取

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    roomId = query.roomId,
  }
  return request(
    "/api/listen/together/sync/playlist/get",
    data,
    createOption(query)
  )
end
