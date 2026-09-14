-- 助眠解压 - 特定时间场景下的推荐资源

local createOption = require("ncm.util.option")
return function(query, request)
  local data = {
    firstQuery = false,
  }
  return request(
    "/api/voice/sati/timescene/resources/get",
    data,
    createOption(query)
  )
end
