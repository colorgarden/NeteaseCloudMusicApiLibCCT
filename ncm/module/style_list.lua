-- 曲风列表

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/tag/list/get", data, createOption(query, "weapi"))
end
