-- 获取专辑歌曲的音质

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/album/privilege", data, createOption(query))
end
