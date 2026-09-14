-- 用户详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local res = request(
    "/api/v1/user/detail/" .. js.tostr(query.uid),
    {},
    createOption(query, "weapi")
  )
  local result = js.replaceAll(json.encode(res), "avatarImgId_str", "avatarImgIdStr")
  return json.decode(result)
end
