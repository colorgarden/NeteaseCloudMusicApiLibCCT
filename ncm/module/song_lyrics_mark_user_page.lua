-- 歌词摘录 - 我的歌词本

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 10),
    offset = js.or_(query.offset, 0),
  }
  return request(
    "/api/song/play/lyrics/mark/user/page",
    data,
    createOption(query)
  )
end
