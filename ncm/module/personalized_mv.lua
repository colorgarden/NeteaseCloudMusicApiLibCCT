-- 推荐MV

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/personalized/mv", {}, createOption(query, "weapi"))
end
