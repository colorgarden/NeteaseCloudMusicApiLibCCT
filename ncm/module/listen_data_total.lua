-- 听歌足迹 - 总收听时长
local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/content/activity/listen/data/total",
    {},
    createOption(query)
  )
end
