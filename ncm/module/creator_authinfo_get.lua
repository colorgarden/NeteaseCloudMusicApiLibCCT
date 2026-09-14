-- 获取达人用户信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/user/creator/authinfo/get", data, createOption(query))
end
