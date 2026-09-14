-- 会员任务

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/vipnewcenter/app/level/task/list", data, createOption(query, "weapi"))
end
