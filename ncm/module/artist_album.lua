-- 歌手专辑列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    total = true,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/artist/albums/" .. js.tostr(query.id),
    data,
    createOption(query, "weapi")
  )
end
