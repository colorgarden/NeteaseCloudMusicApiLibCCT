-- 歌手简要百科信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    artistId = query.id,
  }
  return request("/api/rep/ugc/artist/get", data, createOption(query))
end
