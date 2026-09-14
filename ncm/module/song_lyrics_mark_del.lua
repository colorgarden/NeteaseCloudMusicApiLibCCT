-- 歌词摘录 - 删除摘录歌词

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    markIds = query.id,
  }
  return request("/api/song/play/lyrics/mark/del", data, createOption(query))
end
