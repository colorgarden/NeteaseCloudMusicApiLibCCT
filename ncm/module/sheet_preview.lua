-- 乐谱预览
local createOption = require("ncm.util.option")
return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/music/sheet/preview/info", data, createOption(query))
end
