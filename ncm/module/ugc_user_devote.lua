-- 用户贡献条目、积分、云贝数量
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/rep/ugc/user/devote", data, createOption(query))
end
