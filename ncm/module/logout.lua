-- 退出登录

local createOption = require("ncm.util.option")

return function(query, request)
  return request("/api/logout", {}, createOption(query))
end
