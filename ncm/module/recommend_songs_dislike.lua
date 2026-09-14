-- 每日推荐歌曲-不感兴趣
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    resId = query.id, -- 日推歌曲id
    resType = 4,
    sceneType = 1,
  }
  return request(
    "/api/v2/discovery/recommend/dislike",
    data,
    createOption(query, "weapi")
  )
end
