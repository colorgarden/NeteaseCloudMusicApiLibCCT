-- 视频评论

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    rid = query.id,
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
    beforeTime = js.or_(query.before, 0),
  }
  query.crypto = js.or_(query.crypto, "weapi")
  return request(
    "/api/v1/resource/comments/R_VI_62_" .. js.tostr(query.id),
    data,
    createOption(query, "weapi")
  )
end
