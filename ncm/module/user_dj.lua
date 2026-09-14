-- 用户电台节目

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
  }
  return request(
    "/api/dj/program/" .. js.tostr(query.uid),
    data,
    createOption(query, "weapi")
  )
end
