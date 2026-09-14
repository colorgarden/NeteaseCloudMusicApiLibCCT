-- 获取音乐人任务

local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request(
    "/api/nmusician/workbench/mission/cycle/list",
    data,
    createOption(query, "weapi")
  )
end
