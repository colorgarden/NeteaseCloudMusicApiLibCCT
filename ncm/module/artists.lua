-- 歌手单曲

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  return request(
    "/api/v1/artist/" .. js.tostr(query.id),
    {},
    createOption(query, "weapi")
  )
end
