-- ncm/init.lua
-- Aggregator entry point. Mirrors NeteaseCloudMusicApi's main.js:
--   local ncm = require("ncm")
--   local res = ncm.song_url_v1({ id = 123, level = "standard" })
--
-- Every file in ncm/module/*.lua is exposed under its base name. String cookies
-- are converted to a table before dispatch, exactly like the Node wrapper.

local index = require("ncm.util.index")
local requestModule = require("ncm.util.request")
local request = requestModule.request

local M = {}
M.request = request
M.util = {
  index = index,
  crypto = require("ncm.util.crypto"),
  json = require("ncm.util.json"),
  md5 = require("ncm.util.md5"),
  config = require("ncm.util.config"),
}

-- Directory of this file.
local function selfDir()
  local info = debug and debug.getinfo and debug.getinfo(1, "S")
  local src = info and info.source or ""
  local path = src:match("^@(.*)$") or src
  return (path:match("^(.*)[/\\]") or ".")
end

-- Discover module names. Prefer the filesystem (CC), then a generated manifest.
local function discoverModules()
  local names = {}

  local okFs, fsApi = pcall(require, "fs")
  if okFs and fsApi and fsApi.list then
    local ok, entries = pcall(fsApi.list, selfDir() .. "/module")
    if ok then
      for _, f in ipairs(entries) do
        local name = f:match("^(.-)%.lua$")
        if name then names[#names + 1] = name end
      end
    end
  end

  if #names == 0 then
    local ok, manifest = pcall(require, "ncm.manifest")
    if ok and type(manifest) == "table" then
      for _, name in ipairs(manifest) do names[#names + 1] = name end
    end
  end

  table.sort(names)
  return names
end

local function wrap(mod)
  return function(data)
    data = data or {}
    local cookie = data.cookie
    if type(cookie) == "string" then
      cookie = index.cookieToJson(cookie)
    end
    if type(cookie) ~= "table" then cookie = {} end

    local q = {}
    for k, v in pairs(data) do q[k] = v end
    q.cookie = cookie
    return mod(q, request)
  end
end

for _, name in ipairs(discoverModules()) do
  local ok, mod = pcall(require, "ncm.module." .. name)
  if ok and type(mod) == "function" then
    M[name] = wrap(mod)
  end
end

return M
