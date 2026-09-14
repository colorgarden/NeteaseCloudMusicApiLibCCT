-- 助眠解压 - 标签列表

local createOption = require("ncm.util.option")
return function(query, request)
  local data = {}
  return request("/api/voice/sati/tag/list", data, createOption(query))
end
