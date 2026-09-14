-- MV排行榜

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    area = js.or_(query.area, ""),
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    total = true,
  }
  return request("/api/mv/toplist", data, createOption(query, "weapi"))
end
