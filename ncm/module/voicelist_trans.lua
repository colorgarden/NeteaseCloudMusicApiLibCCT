local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    limit = js.or_(query.limit, "200"), -- 每页数量
    offset = js.or_(query.offset, "0"), -- 偏移量
    radioId = js.or_(query.radioId, json.null), -- 电台id
    programId = js.or_(query.programId, "0"), -- 节目id
    position = js.or_(query.position, "1"), -- 排序编号
  }
  return request("/api/voice/workbench/radio/program/trans", data, createOption(query))
end
