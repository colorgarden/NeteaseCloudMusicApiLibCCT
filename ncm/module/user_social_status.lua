-- 用户状态
local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/social/user/status",
    {
      visitorId = query.uid,
    },
    createOption(query)
  )
end
