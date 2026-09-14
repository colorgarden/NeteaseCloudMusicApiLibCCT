-- 相似歌曲

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
return function(query, request)
  local data = {
    songid = query.id,
    limit = js.or_(query.limit, 50),
    offset = js.or_(query.offset, 0),
  }
  return request(
    "/api/v1/discovery/simiSong",
    data,
    createOption(query, "weapi")
  )
end
