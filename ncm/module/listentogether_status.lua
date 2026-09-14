-- 一起听状态

local createOption = require("ncm.options")

return function(query, request)
  return request(
    "/api/listen/together/status/get",
    {},
    createOption(query, "weapi")
  )
end
