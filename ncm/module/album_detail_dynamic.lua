-- 专辑动态信息
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/album/detail/dynamic",
    data,
    createOption(query, "weapi")
  )
end
