-- 获取指定维度音乐排行榜列表

local createOption = require("ncm.options")

return function(query, request)
  local data = {
    chartCode = query.chartCode,
    targetId = query.targetId,
    targetType = query.targetType,
  }
  return request("/api/chart/song/detail", data, createOption(query))
end
