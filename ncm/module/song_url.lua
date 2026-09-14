-- 歌曲链接
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local ids = js.split(js.tostr(query.id), ",")
  local data = {
    ids = json.encode(ids),
    br = math.floor(tonumber(js.or_(query.br, 999000))),
  }
  local res = request(
    "/api/song/enhance/player/url",
    data,
    createOption(query)
  )
  -- 根据id排序
  local result = res.body.data
  table.sort(result, function(a, b)
    return js.indexOf(ids, js.tostr(a.id)) - js.indexOf(ids, js.tostr(b.id))
  end)
  return {
    status = 200,
    body = {
      code = 200,
      data = result,
    },
  }
end
