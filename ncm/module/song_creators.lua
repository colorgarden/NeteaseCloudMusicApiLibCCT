-- 歌曲创作者信息

local createOption = require("ncm.util.option")
return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/song/creators", data, createOption(query))
end
