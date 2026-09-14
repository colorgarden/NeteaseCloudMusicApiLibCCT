-- 歌词
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
    tv = -1,
    lv = -1,
    rv = -1,
    kv = -1,
    _nmclfl = 1,
  }
  return request("/api/song/lyric", data, createOption(query))
end
