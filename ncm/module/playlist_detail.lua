-- 歌单详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    n = 100000,
    s = js.or_(query.s, 8),
  }
  return request("/api/v6/playlist/detail", data, createOption(query))
end
