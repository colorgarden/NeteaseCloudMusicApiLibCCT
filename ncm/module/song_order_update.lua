-- 更新歌曲顺序

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    pid = query.pid,
    trackIds = query.ids,
    op = "update",
  }

  return request("/api/playlist/manipulate/tracks", data, createOption(query))
end
