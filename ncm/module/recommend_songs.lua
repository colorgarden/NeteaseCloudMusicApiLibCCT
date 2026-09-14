-- 每日推荐歌曲

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/v3/discovery/recommend/songs",
    data,
    createOption(query, "weapi")
  )
end
