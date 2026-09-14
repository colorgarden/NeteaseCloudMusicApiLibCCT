-- 歌曲动态封面

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/songplay/dynamic-cover", data, createOption(query))
end
