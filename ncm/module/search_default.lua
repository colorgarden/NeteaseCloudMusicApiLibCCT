-- 默认搜索关键词

local createOption = require("ncm.util.option")
return function(query, request)
  return request("/api/search/defaultkeyword/get", {}, createOption(query))
end
