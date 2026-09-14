-- 相似歌手
local createOption = require("ncm.util.option")
return function(query, request)
  local data = {
    artistid = query.id,
  }
  return request(
    "/api/discovery/simiArtist",
    data,
    createOption(query, "weapi")
  )
end
