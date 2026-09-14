-- 专辑简要百科信息
local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    albumId = query.id,
  }
  return request("/api/rep/ugc/album/get", data, createOption(query))
end
