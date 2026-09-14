-- 新版歌词 - 包含逐字歌词

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
    cp = false,
    tv = 0,
    lv = 0,
    rv = 0,
    kv = 0,
    yv = 0,
    ytv = 0,
    yrv = 0,
  }
  return request("/api/song/lyric/v1", data, createOption(query))
end
