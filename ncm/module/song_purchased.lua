-- 已购单曲

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
  }
  return request(
    "/api/single/mybought/song/list",
    data,
    createOption(query, "weapi")
  )
end
