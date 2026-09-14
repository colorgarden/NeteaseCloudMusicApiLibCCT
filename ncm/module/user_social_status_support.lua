-- 用户状态 - 支持设置的状态
local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/social/user/status/support", {}, createOption(query))
end
