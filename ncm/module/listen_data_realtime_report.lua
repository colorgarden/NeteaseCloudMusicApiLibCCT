-- 听歌足迹 - 本周/本月收听时长
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  return request(
    "/api/content/activity/listen/data/realtime/report",
    {
      type = js.or_(query.type, "week"), --周 week 月 month
    },
    createOption(query)
  )
end
