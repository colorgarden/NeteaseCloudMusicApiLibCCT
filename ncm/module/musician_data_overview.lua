-- 音乐人数据概况

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/creator/musician/statistic/data/overview/get",
    data,
    createOption(query, "weapi")
  )
end
