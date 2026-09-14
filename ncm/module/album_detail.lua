-- 数字专辑详情
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/vipmall/albumproduct/detail",
    data,
    createOption(query, "weapi")
  )
end
