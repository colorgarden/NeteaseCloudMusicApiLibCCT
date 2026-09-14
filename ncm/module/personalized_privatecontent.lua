-- 独家放送

local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/personalized/privatecontent",
    {},
    createOption(query, "weapi")
  )
end
