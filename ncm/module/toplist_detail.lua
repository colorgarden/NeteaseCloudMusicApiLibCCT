-- 所有榜单内容摘要

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/toplist/detail", {}, createOption(query, "weapi"))
end
