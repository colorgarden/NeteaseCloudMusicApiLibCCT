-- 歌单导入 - 任务状态
local createOption = require("ncm.util.option")
local json = require("ncm.util.json")

return function(query, request)
  return request(
    "/api/playlist/import/task/status/v2",
    {
      taskIds = "[" .. json.encode(query.id) .. "]",
    },
    createOption(query)
  )
end
