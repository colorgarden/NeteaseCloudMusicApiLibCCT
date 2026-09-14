-- 粉丝省份比例
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/fanscenter/basicinfo/province/get",
    data,
    createOption(query)
  )
end
