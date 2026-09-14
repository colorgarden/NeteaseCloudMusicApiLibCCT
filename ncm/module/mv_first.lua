-- 最新MV

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    -- 'offset': query.offset || 0,
    area = js.or_(query.area, ""),
    limit = js.or_(query.limit, 30),
    total = true,
  }
  return request("/api/mv/first", data, createOption(query))
end
