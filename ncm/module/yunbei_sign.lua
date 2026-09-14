local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  return request("/api/pointmall/user/sign", data, createOption(query, "weapi"))
end
