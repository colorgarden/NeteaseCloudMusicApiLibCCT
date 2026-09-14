-- 账号云豆数

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/cloudbean/get", data, createOption(query, "weapi"))
end
