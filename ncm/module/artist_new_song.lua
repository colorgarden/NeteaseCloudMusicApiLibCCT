local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 20),
    startTimestamp = js.or_(query.before, js.now()),
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/sub/artist/new/works/song/list",
    data,
    createOption(query, "weapi")
  )
end
