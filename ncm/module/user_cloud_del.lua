-- 云盘歌曲删除

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    songIds = { query.id },
  }
  return request("/api/cloud/del", data, createOption(query, "weapi"))
end
