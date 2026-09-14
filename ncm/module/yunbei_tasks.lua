local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/usertool/task/list/all", data, createOption(query, "weapi"))
end
