-- 用户徽章
local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/medal/user/page",
    {
      uid = query.uid,
    },
    createOption(query)
  )
end
