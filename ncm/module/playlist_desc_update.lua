-- 更新歌单描述

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
    desc = query.desc,
  }
  return request("/api/playlist/desc/update", data, createOption(query))
end
