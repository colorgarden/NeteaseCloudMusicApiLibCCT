-- 网易出品

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    offset = js.or_(query.offset, 0),
    limit = js.or_(query.limit, 30),
  }
  return request("/api/mv/exclusive/rcmd", data, createOption(query))
end
