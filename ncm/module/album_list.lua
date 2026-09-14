-- 数字专辑-新碟上架
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, 30),
    offset = js.or_(query.offset, 0),
    total = true,
    area = js.or_(query.area, "ALL"), --ALL:全部,ZH:华语,EA:欧美,KR:韩国,JP:日本
    type = query.type,
  }
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/vipmall/albumproduct/list",
    data,
    createOption(query, "weapi")
  )
end
