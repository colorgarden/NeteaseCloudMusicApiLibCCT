-- 数字专辑销量

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    albumIds = query.ids,
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request(
    "/api/vipmall/albumproduct/album/query/sales",
    data,
    createOption(query, "weapi")
  )
end
