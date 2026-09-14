-- 数字专辑详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request(
    "/api/vipmall/albumproduct/detail",
    data,
    createOption(query, "weapi")
  )
end
