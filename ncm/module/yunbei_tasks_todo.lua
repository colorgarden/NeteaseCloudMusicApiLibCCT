local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/usertool/task/todo/query", data, createOption(query, "weapi"))
end
