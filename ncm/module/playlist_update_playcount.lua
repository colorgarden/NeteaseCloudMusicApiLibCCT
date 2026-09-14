-- 歌单打卡

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/playlist/update/playcount", data, createOption(query))
end
