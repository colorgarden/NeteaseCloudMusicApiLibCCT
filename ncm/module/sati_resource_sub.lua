-- 助眠解压 - 收藏

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    cancel = js.or_(query.cancel, false),
  }
  return request("/api/voice/sati/resource/sub", data, createOption(query))
end
