-- 私信和通知接口
local createOption = require("ncm.util.option")
return function(query, request)
  local data = {}
  return request("/api/pl/count", data, createOption(query, "weapi"))
end
