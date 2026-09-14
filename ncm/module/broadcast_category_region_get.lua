-- 广播电台 - 分类/地区信息

local createOption = require("ncm.options")

return function(query, request)
  local data = {}
  return request(
    "/api/voice/broadcast/category/region/get",
    data,
    createOption(query)
  )
end
