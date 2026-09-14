--热门话题

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
  }
  return request("/api/act/hot", data, createOption(query, "weapi"))
end
