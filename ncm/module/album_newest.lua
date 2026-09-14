-- 最新专辑

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/discovery/newAlbum", {}, createOption(query, "weapi"))
end
