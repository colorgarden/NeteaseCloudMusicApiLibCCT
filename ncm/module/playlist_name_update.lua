-- 更新歌单名

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
    name = query.name,
  }
  return request("/api/playlist/update/name", data, createOption(query))
end
