-- 获取达人达标信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/influencer/web/apply/threshold/detail/get",
    data,
    createOption(query)
  )
end
