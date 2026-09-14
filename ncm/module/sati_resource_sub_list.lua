-- 助眠解压 - 收藏列表

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/voice/sati/resource/sub/list", data, createOption(query))
end
