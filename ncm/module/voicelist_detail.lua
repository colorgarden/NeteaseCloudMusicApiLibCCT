local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    id = query.id,
  }
  return request("/api/voice/workbench/voicelist/detail", data, createOption(query))
end
