-- 热门搜索

local createOption = require("ncm.util.option")
return function(query, request)
  local data = {
    type = 1111,
  }
  return request("/api/search/hot", data, createOption(query))
end
