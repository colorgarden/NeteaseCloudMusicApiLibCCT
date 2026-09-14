-- 云随机播放
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    ids = query.ids,
  }
  return request("/api/playmode/song/vector/get", data, createOption(query))
end
