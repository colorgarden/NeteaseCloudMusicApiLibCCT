-- 红心与取消红心歌曲

local createOption = require("ncm.options")

return function(query, request)
  if query.like == "false" then
    query.like = false
  else
    query.like = true
  end
  local data = {
    alg = "itembased",
    trackId = query.id,
    like = query.like,
    time = "3",
  }
  return request("/api/radio/like", data, createOption(query, "weapi"))
end
