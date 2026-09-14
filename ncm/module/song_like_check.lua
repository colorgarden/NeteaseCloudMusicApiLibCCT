-- 歌曲是否喜爱

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    trackIds = query.ids,
  }
  return request("/api/song/like/check", data, createOption(query))
end
