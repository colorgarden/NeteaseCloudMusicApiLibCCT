-- 歌单收藏者

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
  }
  return request("/api/playlist/subscribers", data, createOption(query))
end
