--声音搜索
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, "200"),
    offset = js.or_(query.offset, "0"),
    name = js.or_(query.name, json.null),
    displayStatus = js.or_(query.displayStatus, json.null),
    type = js.or_(query.type, json.null),
    voiceFeeType = js.or_(query.voiceFeeType, json.null),
    radioId = query.voiceListId,
  }
  return request("/api/voice/workbench/voice/list", data, createOption(query))
end
