-- 收藏与取消收藏歌手

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.t = js.ternary(tonumber(query.t) == 1, "sub", "unsub")
  local data = {
    artistId = query.id,
    artistIds = "[" .. js.tostr(query.id) .. "]",
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/artist/" .. js.tostr(query.t), data, createOption(query, "weapi"))
end
