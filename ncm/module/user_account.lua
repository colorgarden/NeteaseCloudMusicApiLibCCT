local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/nuser/account/get", data, createOption(query, "weapi"))
end
