-- 独家放送列表

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    offset = js.or_(query.offset, 0),
    total = "true",
    limit = js.or_(query.limit, 60),
  }
  return request(
    "/api/v2/privatecontent/list",
    data,
    createOption(query, "weapi")
  )
end
