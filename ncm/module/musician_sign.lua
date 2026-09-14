-- 音乐人签到

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/creator/user/access", data, createOption(query, "weapi"))
end
