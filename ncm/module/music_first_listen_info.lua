-- 回忆坐标

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request(
    "/api/content/activity/music/first/listen/info",
    data,
    createOption(query)
  )
end
