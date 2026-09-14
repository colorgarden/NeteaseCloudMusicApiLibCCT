local index = require("ncm.util.index")
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local uri = query.uri
  local data = {}
  local ok = pcall(function()
    local d
    if type(query.data) == "string" then
      d = json.decode(query.data)
    else
      d = js.or_(query.data, {})
    end
    if type(d.cookie) == "string" then
      d.cookie = index.cookieToJson(d.cookie)
      query.cookie = d.cookie
    end
    data = d
  end)
  if not ok then
    data = {}
  end

  local crypto = js.or_(query.crypto, "")

  local res = request(uri, data, createOption(query, crypto))
  return res
end
