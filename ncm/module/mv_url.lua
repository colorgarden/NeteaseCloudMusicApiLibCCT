-- MV链接

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    r = js.or_(query.r, 1080),
  }
  return request(
    "/api/song/enhance/play/mv/url",
    data,
    createOption(query, "weapi")
  )
end
