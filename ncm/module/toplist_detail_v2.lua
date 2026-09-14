-- 所有榜单内容摘要v2

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/toplist/detail/v2", {}, createOption(query, "weapi"))
end
