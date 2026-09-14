-- 歌手动态信息

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/artist/detail/dynamic", data, createOption(query))
end
