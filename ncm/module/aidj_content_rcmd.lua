-- 私人 DJ

-- 实际请求参数如下, 部分内容省略, 敏感信息已进行混淆
-- 可按需修改此 API 的代码
-- {"extInfo":"{\"lastRequestTimestamp\":1692358373509,\"lbsInfoList\":[{\"lat\":40.23076381,\"lon\":129.07545186,\"time\":1692358543},{\"lat\":40.23076381,\"lon\":129.07545186,\"time\":1692055283}],\"listenedTs\":false,\"noAidjToAidj\":true}","header":"{}"}

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  -- Build the JSON text manually: JSON.stringify preserves JS insertion order,
  -- while Lua's json.encode iterates with pairs(). Field order must match.
  local parts = {}
  if query.latitude ~= nil then
    parts[#parts + 1] = '"lbsInfoList":[{"lat":' .. json.encode(query.latitude)
      .. ',"lon":' .. json.encode(query.longitude)
      .. ',"time":' .. json.encode(js.now() / 1000) .. "}]"
  end
  parts[#parts + 1] = '"noAidjToAidj":false'
  parts[#parts + 1] = '"lastRequestTimestamp":' .. json.encode(js.now())
  parts[#parts + 1] = '"listenedTs":false'

  local data = {
    extInfo = "{" .. table.concat(parts, ",") .. "}",
  }
  -- console.log(data)
  return request("/api/aidj/content/rcmd/info", data, createOption(query))
end
