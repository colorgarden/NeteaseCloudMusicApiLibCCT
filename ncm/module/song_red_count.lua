-- 歌曲红心数量

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/song/red/count", data, createOption(query))
end
