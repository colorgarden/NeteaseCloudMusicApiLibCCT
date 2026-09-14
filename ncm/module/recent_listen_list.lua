-- 最近听歌列表

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/pc/recent/listen/list", data, createOption(query))
end
