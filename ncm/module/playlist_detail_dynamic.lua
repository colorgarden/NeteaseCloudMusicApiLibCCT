-- 歌单动态信息

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    n = 100000,
    s = js.or_(query.s, 8),
  }
  return request("/api/playlist/detail/dynamic", data, createOption(query))
end
