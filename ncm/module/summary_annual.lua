-- 年度听歌报告2017-2024
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {}
  local key = js.ternary(
    js.indexOf({ "2017", "2018", "2019" }, query.year) > -1,
    "userdata",
    "data"
  )
  return request(
    "/api/activity/summary/annual/" .. js.tostr(query.year) .. "/" .. key,
    data,
    createOption(query)
  )
end
