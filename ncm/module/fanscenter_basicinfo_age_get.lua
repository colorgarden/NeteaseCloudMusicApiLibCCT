-- 粉丝年龄比例
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/fanscenter/basicinfo/age/get", data, createOption(query))
end
