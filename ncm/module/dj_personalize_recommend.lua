-- 电台个性推荐

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  query.crypto = js.or_(query.crypto, "weapi")
  return request(
    "/api/djradio/personalize/rcmd",
    {
      limit = js.or_(query.limit, 6),
    },
    createOption(query, "weapi")
  )
end
