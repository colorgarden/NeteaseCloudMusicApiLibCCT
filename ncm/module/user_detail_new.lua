-- 用户详情

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    all = "true",
    userId = query.uid,
  }
  local res = request(
    "/api/w/v1/user/detail/" .. js.tostr(query.uid),
    data,
    createOption(query, "eapi")
  )
  -- local result = js.replaceAll(json.encode(res), "avatarImgId_str", "avatarImgIdStr")
  -- return json.decode(result)
  return res
end
