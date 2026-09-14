-- 推荐电台

local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/personalized/djprogram",
    {},
    createOption(query, "weapi")
  )
end
