-- DIFM电台 - 收藏列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    sources = js.or_(query.sources, "[0]"),
  }
  return request(
    "/api/dj/difm/subscribe/channels/get/v2",
    data,
    createOption(query)
  )
end
