-- 用户状态 - 相同状态的用户
local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/social/user/status/rcmd", {}, createOption(query))
end
