-- 数字专辑-语种风格馆
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 10),
    offset = js.or_(query.offset, 0),
    total = true,
    area = js.or_(query.area, "Z_H"), --Z_H:华语,E_A:欧美,KR:韩国,JP:日本
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/vipmall/appalbum/album/style",
    data,
    createOption(query, "weapi")
  )
end
