-- 最近联系

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/msg/recentcontact/get",
    data,
    createOption(query, "weapi")
  )
end
