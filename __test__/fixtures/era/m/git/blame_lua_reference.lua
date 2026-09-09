--- Frozen pre-native blame query and parser; differential oracle only.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.blame_lua_reference" ---@type string
local CANCELLED = "blame:cancelled"

---@param output                     string
---@return table<integer, era.m.git.BlameInfo>
local function parse_blame_output(output)
  local result = {} ---@type table<integer, era.m.git.BlameInfo>
  local lines = vim.split(output, "\n", { plain = true })

  local current_sha = nil ---@type string|nil
  local current_info = nil ---@type era.m.git.BlameInfo|nil
  local commits = {} ---@type table<string, era.m.git.BlameInfo>

  for _, line in ipairs(lines) do
    if line == "" then
      goto continue
    end

    local sha, orig_lnum, final_lnum, num_lines = line:match("^(%x+)%s+(%d+)%s+(%d+)%s*(%d*)$")
    if sha then
      current_sha = sha
      local existing = commits[sha]
      if existing then
        current_info = vim.tbl_extend("force", {}, existing)
      else
        current_info = {
          sha = sha,
          abbrev_sha = sha:sub(1, 8),
          author = "",
          author_mail = "",
          author_time = 0,
          author_tz = "",
          committer = "",
          committer_mail = "",
          committer_time = 0,
          committer_tz = "",
          summary = "",
          previous = nil,
          previous_filename = nil,
          filename = "",
          orig_lnum = tonumber(orig_lnum) or 0,
          final_lnum = tonumber(final_lnum) or 0,
          num_lines = tonumber(num_lines) or 1,
        }
      end
      current_info.orig_lnum = tonumber(orig_lnum) or 0
      current_info.final_lnum = tonumber(final_lnum) or 0
      current_info.num_lines = tonumber(num_lines) or 1
      goto continue
    end

    if current_info then
      if line:sub(1, 1) == "\t" then
        if current_sha and current_info then
          if not commits[current_sha] then
            commits[current_sha] = current_info
          end
          result[current_info.final_lnum] = current_info
        end
        current_info = nil
        goto continue
      end

      local key, value = line:match("^([%w-]+)%s+(.*)$")
      if key then
        if key == "author" then
          current_info.author = value
        elseif key == "author-mail" then
          current_info.author_mail = value:gsub("^<", ""):gsub(">$", "")
        elseif key == "author-time" then
          current_info.author_time = tonumber(value) or 0
        elseif key == "author-tz" then
          current_info.author_tz = value
        elseif key == "committer" then
          current_info.committer = value
        elseif key == "committer-mail" then
          current_info.committer_mail = value:gsub("^<", ""):gsub(">$", "")
        elseif key == "committer-time" then
          current_info.committer_time = tonumber(value) or 0
        elseif key == "committer-tz" then
          current_info.committer_tz = value
        elseif key == "summary" then
          current_info.summary = value
        elseif key == "previous" then
          local prev_sha, prev_file = value:match("^(%x+)%s+(.*)$")
          if prev_sha then
            current_info.previous = prev_sha
            current_info.previous_filename = prev_file
          end
        elseif key == "filename" then
          current_info.filename = value
        end
      end
    end

    ::continue::
  end

  return result
end

--- Run `git blame --porcelain` against the current buffer document. The returned Future ALWAYS settles:
--- resolve(map) on success, reject(err) on a git error, reject(CANCELLED) when the
--- token fires. Settling on cancel is the whole point - the caller's `:finally`
--- runs in every case, so an in-flight marker can never leak (the historical bug).
---@param bufnr                      integer
---@param relpath                    string
---@param cwd                        string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with table<integer, era.m.git.BlameInfo>
local function run_blame(bufnr, relpath, cwd, token)
  ---@diagnostic disable-next-line: redundant-parameter -- LuaLS selects the one-argument overload for Future.new.
  return stl.c.Future.new(function(resolve, reject)
    if token and token:is_cancelled() then
      reject(CANCELLED)
      return
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      reject(CANCELLED)
      return
    end

    local contents, encode_err = era.m.git.staging.encode(era.m.git.staging.from_buffer(bufnr))
    if not contents then
      reject(encode_err or "Failed to encode buffer content")
      return
    end

    local settled = false ---@type boolean
    local proc = nil ---@type vim.SystemObj|nil
    local timer = vim.uv.new_timer() ---@type uv.uv_timer_t|nil
    local cancellation = nil ---@type stl.c.IUnsubscribable|nil

    ---@param ok                         boolean
    ---@param result                     table<integer, era.m.git.BlameInfo>|string
    ---@return nil
    local function finish(ok, result)
      if settled then
        return
      end
      settled = true
      if cancellation then
        cancellation:unsubscribe()
        cancellation = nil
      end
      if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      if ok then
        resolve(result)
      else
        reject(result)
      end
    end

    local spawned, result = pcall(
      vim.system,
      { "git", "-C", cwd, "blame", "--porcelain", "--contents", "-", "--", relpath },
      {
        stdin = contents,
        text = false,
      },
      function(obj)
        vim.schedule(function()
          if obj.code ~= 0 then
            local err = vim.trim(obj.stderr or "")
            finish(false, err ~= "" and err or string.format("git blame failed (exit %d)", obj.code))
            return
          end
          finish(true, parse_blame_output(obj.stdout or ""))
        end)
      end
    )
    if not spawned then
      finish(false, tostring(result))
      return
    end
    proc = result

    if timer then
      timer:start(30000, 0, function()
        if proc then
          pcall(proc.kill, proc, 15)
        end
        vim.schedule(function()
          finish(false, "git blame timed out after 30000ms")
        end)
      end)
    end

    if token then
      cancellation = token:on_cancel(function()
        if proc then
          pcall(proc.kill, proc, 15)
        end
        finish(false, CANCELLED)
      end)
    end
  end)
end

return { parse = parse_blame_output, collect = run_blame }
