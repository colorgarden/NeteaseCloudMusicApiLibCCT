-- 收藏计数

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/subcount", {}, createOption(query, "weapi"))
end
