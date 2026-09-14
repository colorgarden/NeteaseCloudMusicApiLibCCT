-- 每日推荐歌单

local createOption = require("ncm.util.option")

return function(query, request)
  return request(
    "/api/v1/discovery/recommend/resource",
    {},
    createOption(query, "weapi")
  )
end
