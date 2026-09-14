-- 歌曲简要百科信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songId = query.id,
  }
  return request("/api/rep/ugc/song/get", data, createOption(query))
end
