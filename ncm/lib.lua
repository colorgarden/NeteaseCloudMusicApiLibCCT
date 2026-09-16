-- ncm/lib.lua
-- Locates the directory that holds this library's third-party dependencies
-- (aeslua-cc, cc_big_http, cc_speakerlib) and puts it on `package.path`.
--
-- WHY THIS EXISTS
--   CC resolves every entry of `package.path` relative to the *running
--   program's* directory, and `require` is the only directory-aware loader.
--   Keeping the dependencies inside the library (`<package root>/lib/`) means a
--   single `/ncm` directory holds everything and can be deleted to uninstall.
--
-- HOW THE PACKAGE ROOT IS FOUND
--   CC's `package.searchpath` returns an already-resolved path and prefixes any
--   relative pattern with the program's directory, so asking for this very
--   module ("ncm.lib") yields something like "/ncm/lib.lua". Its parent
--   directory is the package root, wherever the library was installed. If that
--   lookup is unavailable we fall back to the default install root "/ncm".
--
--   `M.dir` is then used both as a `package.path` prefix (dir-aware) and, when
--   an absolute path is required, as the base for the files inside it
--   (`<M.dir>/cc_big_http.lua`, `<M.dir>/speaker.lua`).

local M = {}

-- CC's `require` calls the module chunk as `chunk(name, resolvedPath)`, so the
-- module's own name is the first vararg. Capture it at chunk level: `...` is
-- only valid directly inside a vararg function.
local moduleName = ...

local function findPackageRoot(name)
  local pkg = package
  local searchpath = pkg and pkg.searchpath
  if searchpath and pkg.path and type(name) == "string" and name ~= "" then
    local ok, resolved = pcall(searchpath, name, pkg.path)
    if ok and type(resolved) == "string" then
      local root = resolved:match("^(.*)[/\\][^/\\]*$")
      if root then return root end
    end
  end
  return "/ncm"
end

M.dir = findPackageRoot(moduleName) .. "/lib"

-- Make the dependency directory importable. Idempotent: requiring this module
-- twice must not keep prepending to package.path.
if type(package) == "table" and type(package.path) == "string" then
  local entries = M.dir .. "/?.lua;" .. M.dir .. "/?/init.lua;"
  if not package.path:find(entries, 1, true) then
    package.path = entries .. package.path
  end
end

return M
