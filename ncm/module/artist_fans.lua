-- 歌手粉丝

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/artist/fans/get", data, createOption(query, "weapi"))
end
