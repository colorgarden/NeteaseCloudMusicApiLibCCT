-- .luacheckrc — configuration for the NeteaseCloudMusicApi CC:Tweaked port.
-- Target runtime: CC:Tweaked (Cobalt / Lua 5.2) with the CC global APIs.
std = "lua52"

read_globals = {
  -- CC:Tweaked global APIs
  "http", "fs", "term", "peripheral", "rednet", "redstone", "turtle",
  "shell", "textutils", "colors", "colours", "keys", "commands",
  "multishell", "paintutils", "pocket", "vector", "gps", "settings",
  "parallel", "sleep", "write", "read", "printError",
  "aeslua",
}

-- Writable globals: tests shim these on the local interpreter.
globals = { "_G", "bit32", "unpack", "print" }

-- CC:Tweaked adds fields to standard globals (os.epoch) and the test harness
-- intentionally overrides globals (math.random), so ignore those two codes.
ignore = { "143", "142", "122" }

-- Module functions legitimately take (query, request) even when one is unused.
unused_args = false
-- `self`-style trailing unused is noise here.
unused_secondaries = false
max_line_length = false

-- Files/dirs to never lint.
exclude_files = {
  "aeslua_cc/**",
  "deps/**",
  "vendor/**",
  "ncm/util/libdeflate.lua",
  "test/node_modules/**",
}
