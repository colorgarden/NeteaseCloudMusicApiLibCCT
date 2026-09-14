-- 精品歌单 tags
local createOption = require("ncm.util.option")
return function(query, request)
  local data = {}
  return request(
    "/api/playlist/highquality/tags",
    data,
    createOption(query, "weapi")
  )
end
