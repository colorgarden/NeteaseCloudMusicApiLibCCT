-- 歌手相关MV

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    artistId = query.id,
    limit = query.limit,
    offset = query.offset,
    total = true,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/artist/mvs", data, createOption(query, "weapi"))
end
