-- 副歌时间
local createOption = require("ncm.util.option")
local json = require("ncm.util.json")
return function(query, request)
  return request(
    "/api/song/chorus",
    {
      ids = "[" .. json.encode(query.id) .. "]",
    },
    createOption(query)
  )
end
