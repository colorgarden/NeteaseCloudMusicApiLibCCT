-- @我

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    offset = js.or_(query.offset, 0),
    limit = js.or_(query.limit, 30),
    total = "true",
  }
  return request("/api/forwards/get", data, createOption(query, "weapi"))
end
