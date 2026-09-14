-- 听歌打卡

local createOption = require("ncm.util.option")
local json = require("ncm.util.json")

return function(query, request)
  -- JSON.stringify preserves JS insertion order, so build the string manually.
  local fields = {}
  fields[#fields + 1] = '"download":0'
  fields[#fields + 1] = '"end":"playend"'
  if query.id ~= nil then
    fields[#fields + 1] = '"id":' .. json.encode(query.id)
  end
  if query.sourceid ~= nil then
    fields[#fields + 1] = '"sourceId":' .. json.encode(query.sourceid)
  end
  if query.time ~= nil then
    fields[#fields + 1] = '"time":' .. json.encode(query.time)
  end
  fields[#fields + 1] = '"type":"song"'
  fields[#fields + 1] = '"wifi":0'
  fields[#fields + 1] = '"source":"list"'
  fields[#fields + 1] = '"mainsite":1'
  fields[#fields + 1] = '"content":""'

  local data = {
    logs = '[{"action":"play","json":{' .. table.concat(fields, ",") .. "}}]",
  }

  return request("/api/feedback/weblog", data, createOption(query, "weapi"))
end
