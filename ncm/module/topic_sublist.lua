-- 收藏的专栏

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 50),
    offset = js.or_(query.offset, 0),
    total = true,
  }
  return request("/api/topic/sublist", data, createOption(query, "weapi"))
end
