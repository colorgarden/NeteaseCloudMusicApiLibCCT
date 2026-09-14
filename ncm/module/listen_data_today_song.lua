-- 听歌足迹 - 今日收听
local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/content/activity/listen/data/today/song/play/rank",
    {},
    createOption(query)
  )
end
