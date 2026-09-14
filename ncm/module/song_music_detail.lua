-- 歌曲音质详情

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/song/music/detail/get", data, createOption(query))
end
