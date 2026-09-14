-- 音乐百科基础信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/song/play/about/block/page", data, createOption(query))
end
