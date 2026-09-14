-- 类别热门电台

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/user/level", data, createOption(query, "weapi"))
end
