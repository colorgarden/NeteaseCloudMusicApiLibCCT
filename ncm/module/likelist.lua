-- 喜欢的歌曲(无序)

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    uid = query.uid,
  }
  return request("/api/song/like/get", data, createOption(query))
end
