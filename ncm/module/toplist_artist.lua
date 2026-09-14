-- 歌手榜

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    type = js.or_(query.type, 1),
    limit = 100,
    offset = 0,
    total = true,
  }
  return request("/api/toplist/artist", data, createOption(query, "weapi"))
end
