local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    actid = query.actid,
  }
  return request("/api/act/detail", data, createOption(query, "weapi"))
end
