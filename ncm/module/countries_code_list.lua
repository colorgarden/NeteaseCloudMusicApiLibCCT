-- 国家编码列表
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/lbs/countries/v1", data, createOption(query))
end
