-- 设置

local createOption = require("ncm.util.option")
return function(query, request)
  local data = {}
  return request("/api/user/setting", data, createOption(query, "weapi"))
end
