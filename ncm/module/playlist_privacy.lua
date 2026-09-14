-- 公开隐私歌单

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
    privacy = 0,
  }
  return request("/api/playlist/update/privacy", data, createOption(query))
end
