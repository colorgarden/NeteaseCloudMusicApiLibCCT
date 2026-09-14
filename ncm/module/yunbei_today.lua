local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/point/today/get", data, createOption(query, "weapi"))
end
