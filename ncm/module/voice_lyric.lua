local createOption = require("ncm.util.option")

return function(query, request)
  local data = {
    programId = query.id,
  }
  return request("/api/voice/lyric/get", data, createOption(query))
end
