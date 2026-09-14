local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 10),
    offset = js.or_(query.offset, 0),
  }
  return request("/api/point/expense", data, createOption(query))
end
