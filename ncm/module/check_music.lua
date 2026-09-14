-- 歌曲可用性

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    ids = "[" .. js.tostr(math.floor(js.tonum(query.id))) .. "]",
    br = math.floor(js.tonum(js.or_(query.br, 999000))),
  }
  local response = request(
    "/api/song/enhance/player/url",
    data,
    createOption(query, "weapi")
  )
  local playable = false
  if response.body.code == 200 then
    if response.body.data[0].code == 200 then
      playable = true
    end
  end
  if playable then
    response.body = { code = 200, success = true, message = "ok" }
    return response
  else
    -- response.status = 404
    response.body = { code = 200, success = false, message = "亲爱的,暂无版权" }
    return response
    -- return Promise.reject(response)
  end
end
