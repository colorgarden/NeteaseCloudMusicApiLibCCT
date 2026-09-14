local createOption = require("ncm.util.option")
return function(query, request)
  local data = {}
  return request("/api/sign/happy/info", data, createOption(query, "weapi"))
end
