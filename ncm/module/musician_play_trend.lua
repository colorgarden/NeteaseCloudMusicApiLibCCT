-- 音乐人歌曲播放趋势

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    startTime = query.startTime,
    endTime = query.endTime,
  }
  return request(
    "/api/creator/musician/play/count/statistic/data/trend/get",
    data,
    createOption(query, "weapi")
  )
end
