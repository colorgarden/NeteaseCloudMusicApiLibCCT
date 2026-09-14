-- 粉丝性别比例
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/fanscenter/basicinfo/gender/get",
    data,
    createOption(query)
  )
end
