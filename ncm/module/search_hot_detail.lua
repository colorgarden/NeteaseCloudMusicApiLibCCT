-- 热搜列表
local createOption = require("ncm.util.option")
return function(query, request)
  local data = {}
  return request("/api/hotsearchlist/get", data, createOption(query, "weapi"))
end
