-- 助眠解压 - 获取标签下资源列表

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    tag = query.tag,
    firstQuery = false,
  }

  return request("/api/voice/sati/resource/list", data, createOption(query))
end
