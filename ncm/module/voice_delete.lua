local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    ids = query.ids,
  }
  return request("/api/content/voice/delete", data, createOption(query))
end
