-- 曲风-歌手

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    cursor = js.or_(query.cursor, 0),
    size = js.or_(query.size, 20),
    tagId = query.tagId,
    sort = 0,
  }
  return request(
    "/api/style-tag/home/artist",
    data,
    createOption(query, "weapi")
  )
end
