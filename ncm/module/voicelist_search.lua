local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    fee = "-1",
    limit = js.or_(query.limit, "200"),
    offset = js.or_(query.offset, "0"),
    podcastName = js.or_(query.podcastName, ""),
  }
  return request("/api/voice/workbench/voicelist/search", data, createOption(query))
end
