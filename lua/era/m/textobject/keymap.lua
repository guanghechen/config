---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.keymap" ---@type string

local Action = require("era.m.textobject.action")
local Find = require("era.m.textobject.find")

local M = {}

---@param value                         any
---@return string
local function literal(value)
  return vim.inspect(value, { newline = "", indent = "" })
end

---@return string|nil
local function read_id()
  local ok, id = pcall(vim.fn.getcharstr)
  if not ok or id == "" or id == "\27" or id == "\3" then
    return nil
  end
  return id
end

---@return string[]|nil
local function read_prompt()
  local edges = {} ---@type string[]
  for _, label in ipairs({ "Left edge: ", "Right edge: " }) do
    local ok, value = pcall(vim.fn.input, { prompt = label, cancelreturn = "" })
    if not ok or value == "" then
      return nil
    end
    edges[#edges + 1] = value
  end
  return edges
end

---@param kind                          era.m.textobject.Kind
---@param mode                          string
---@return string
local function selection(kind, mode)
  local id = read_id()
  if id == nil then
    return mode == "o" and "<Esc>" or ""
  end
  if not Find.is_enabled(vim.api.nvim_get_current_buf()) or not Find.supports(id) then
    local key = kind .. id ---@type string
    return vim.fn.maparg(key, mode) ~= "" and ("<Ignore>" .. key) or key
  end
  local opts = { count = vim.v.count1 } ---@type era.m.textobject.IOptions
  if id == "?" then
    opts.prompt = read_prompt()
    if opts.prompt == nil then
      return "<Esc>"
    end
  end
  if mode == "x" then
    opts.reference = Action.visual_range()
    opts.vis_mode = vim.fn.mode()
  else
    opts.operator_pending = true
    local forced = vim.fn.mode(1):gsub("^no", "") ---@type string
    opts.vis_mode = forced ~= "" and forced or nil
  end
  -- The returned command is recorded by Neovim for dot-repeat; operator ranges are recomputed.
  return string.format("<Cmd>lua era.m.textobject.select(%s,%s,%s)<CR>", literal(kind), literal(id), literal(opts))
end

---@param side                          "left"|"right"
---@return string
local function edge(side)
  local id = read_id()
  if id == nil then
    return "<Esc>"
  end
  if not Find.is_enabled(vim.api.nvim_get_current_buf()) then
    return ""
  end
  local prompt = id == "?" and read_prompt() or nil ---@type string[]|nil
  if id == "?" and prompt == nil then
    return "<Esc>"
  end
  return string.format(
    "<Cmd>lua era.m.textobject.move_edge(%s,%s,%d,%s)<CR>",
    literal(side),
    literal(id),
    vim.v.count1,
    literal(prompt)
  )
end

---@return nil
function M.bindkeys()
  local keymaps = {} ---@type stl.t.IKeymap[]
  for _, mode in ipairs({ "x", "o" }) do
    for _, kind in ipairs({ "a", "i" }) do
      keymaps[#keymaps + 1] = {
        modes = { mode },
        key = kind,
        desc = kind == "a" and "Around textobject" or "Inside textobject",
        expr = true,
        noremap = false,
        callback = function()
          return selection(kind, mode)
        end,
      }
    end
  end
  for key, side in pairs({ ["g["] = "left", ["g]"] = "right" }) do
    keymaps[#keymaps + 1] = {
      modes = { "n", "x", "o" },
      key = key,
      desc = "Textobject " .. side .. " edge",
      expr = true,
      callback = function()
        return edge(side)
      end,
    }
  end

  local targets = {
    { key = "a", capture = "parameter.inner", ends = true },
    { key = "b", capture = "block.outer" },
    { key = "c", capture = "class.outer", ends = true },
    { key = "f", capture = "function.outer", ends = true },
    { key = "s", capture = "local.scope", group = "locals" },
    { key = "z", capture = "fold", group = "folds" },
  }
  for _, target in ipairs(targets) do
    for _, direction in ipairs({ -1, 1 }) do
      for _, use_end in ipairs(target.ends and { false, true } or { false }) do
        local key = (direction < 0 and "[" or "]") .. (use_end and target.key:upper() or target.key) ---@type string
        keymaps[#keymaps + 1] = {
          modes = { "n", "x", "o" },
          key = key,
          expr = true,
          desc = (direction < 0 and "Previous " or "Next ") .. target.capture .. (use_end and " end" or " start"),
          callback = function()
            local winnr = vim.api.nvim_get_current_win() ---@type integer
            if
              not Find.is_enabled(vim.api.nvim_win_get_buf(winnr))
              or (target.key == "c" and vim.api.nvim_get_option_value("diff", { win = winnr }))
            then
              return key
            end
            -- Read the count when the command runs so dot-repeat can replace it.
            return string.format(
              "<Cmd>lua era.m.textobject.move(%s,%s,%d,%s,vim.v.count1)<CR>",
              literal({ target.capture }),
              literal(target.group or "textobjects"),
              direction,
              literal(use_end)
            )
          end,
        }
      end
    end
  end
  stl.nvim.fn.bindkeys(keymaps, { silent = true })

  local objects = {
    { " ", "between spaces" },
    { '"', '" string' },
    { "'", "' string" },
    { "`", "` string" },
    { "(", "() block, trimmed" },
    { ")", "() block" },
    { "[", "[] block, trimmed" },
    { "]", "[] block" },
    { "{", "{} block, trimmed" },
    { "}", "{} block" },
    { "<", "<> block, trimmed" },
    { ">", "<> block" },
    { "?", "prompted delimiters" },
    { "a", "argument" },
    { "b", "bracket block" },
    { "q", "quote" },
    { "c", "class" },
    { "d", "digits" },
    { "e", "subword" },
    { "f", "function" },
    { "g", "entire buffer" },
    { "h", "unstaged Git hunk" },
    { "i", "indent scope" },
    { "m", "comment" },
    { "N", "number" },
    { "o", "block, conditional, loop" },
    { "s", "splitline block" },
    { "S", "syntax scope" },
    { "t", "tag" },
    { "u", "function call" },
    { "U", "function call without receiver" },
  }
  local descriptions = { mode = { "o", "x" } } ---@type table
  for _, prefix in ipairs({ "a", "i" }) do
    for _, object in ipairs(objects) do
      descriptions[#descriptions + 1] = { prefix .. object[1], desc = object[2] }
    end
  end
  era.m.wk.add(descriptions, { notify = false })
end

return M
