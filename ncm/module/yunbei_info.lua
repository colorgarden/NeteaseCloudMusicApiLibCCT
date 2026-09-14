local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/v1/user/info", data, createOption(query, "weapi"))
end
