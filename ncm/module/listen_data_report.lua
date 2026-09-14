-- 听歌足迹 - 周/月/年收听报告
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  return request(
    "/api/content/activity/listen/data/report",
    {
      type = js.or_(query.type, "week"), --周 week 月 month 年 year
      endTime = query.endTime, -- 不填就是本周/月的
    },
    createOption(query)
  )
end
