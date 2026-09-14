local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, "200"),
    offset = js.or_(query.offset, "0"),
    voiceListId = query.voiceListId,
  }
  return request("/api/voice/workbench/voices/by/voicelist", data, createOption(query))
end
