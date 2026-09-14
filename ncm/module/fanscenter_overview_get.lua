-- 粉丝数量
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/fanscenter/overview/get", data, createOption(query))
end
