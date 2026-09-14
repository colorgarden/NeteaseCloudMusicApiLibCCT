local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.ids = js.or_(query.ids, "")
  local trackParts = {}
  for _, item in ipairs(js.split(query.ids, ",")) do
    trackParts[#trackParts + 1] = '{"type":3,"id":' .. json.encode(item) .. "}"
  end
  local data = {
    id = query.pid,
    tracks = "[" .. table.concat(trackParts, ",") .. "]",
  }
  -- console.log(data)

  return request("/api/playlist/track/add", data, createOption(query, "weapi"))
end
