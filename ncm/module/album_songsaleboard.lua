-- 数字专辑&数字单曲-榜单
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    albumType = js.or_(query.albumType, 0), --0为数字专辑,1为数字单曲
  }
  local typ = js.or_(query.type, "daily") -- daily,week,year,total
  if typ == "year" then
    data = js.assign({}, data, { year = query.year })
  end
  if js.falsy(query.crypto) then query.crypto = nil end
  return request(
    "/api/feealbum/songsaleboard/" .. js.tostr(typ) .. "/type",
    data,
    createOption(query, "weapi")
  )
end
