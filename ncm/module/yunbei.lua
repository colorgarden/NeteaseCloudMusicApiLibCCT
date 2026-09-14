local createOption = require("ncm.util.option")

return function(query, request)
  local data = {}
  -- /api/point/today/get
  return request("/api/point/signed/get", data, createOption(query, "weapi"))
end
