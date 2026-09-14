-- 歌词摘录 - 歌词摘录信息

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/song/play/lyrics/mark/song", data, createOption(query))
end
