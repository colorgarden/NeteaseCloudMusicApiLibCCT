-- 更新歌单标签

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
    tags = query.tags,
  }
  return request("/api/playlist/tags/update", data, createOption(query))
end
