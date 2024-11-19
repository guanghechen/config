---! see https://github.com/folke/ts-comments.nvim/blob/2002692ad1d3f6518d016550c20c2a890f0cbf0e/lua/ts-comments/comments.lua#L1

---@alias ghc.dressing.commentstring.ISpec
---| string
---| string[]
---| table<string, string | string[]>

local native_get_option = vim.filetype.get_option

---@type table<string, ghc.dressing.commentstring.ISpec>
local language_map = {
  astro = "<!-- %s -->",
  axaml = "<!-- %s -->",
  bicep = "// %s",
  blueprint = "// %s",
  c = "// %s",
  c_sharp = "// %s",
  clojure = { ";; %s", "; %s" },
  cpp = "// %s",
  cs_project = "<!-- %s -->",
  cue = "// %s",
  fsharp = "// %s",
  fsharp_project = "<!-- %s -->",
  gleam = "// %s",
  glimmer = "{{! %s }}",
  graphql = "# %s",
  handlebars = "{{! %s }}",
  hcl = "# %s",
  html = "<!-- %s -->",
  hyprlang = "# %s",
  ini = "; %s",
  ipynb = "# %s",
  javascript = {
    "// %s", -- default commentstring when no treesitter node matches
    "/* %s */",
    call_expression = "// %s", -- specific commentstring for call_expression
    jsx_attribute = "// %s",
    jsx_element = "{/* %s */}",
    jsx_fragment = "{/* %s */}",
    spread_element = "// %s",
    statement_block = "// %s",
  },
  php = "// %s",
  proto = { "// %s", "/* %s */" },
  rego = "# %s",
  rescript = "// %s",
  rust = { "// %s", "/* %s */" },
  sql = "-- %s",
  styled = "/* %s */",
  svelte = "<!-- %s -->",
  templ = {
    "// %s",
    component_block = "<!-- %s -->",
  },
  terraform = "# %s",
  tsx = {
    "// %s", -- default commentstring when no treesitter node matches
    "/* %s */",
    call_expression = "// %s", -- specific commentstring for call_expression
    jsx_attribute = "// %s",
    jsx_element = "{/* %s */}",
    jsx_fragment = "{/* %s */}",
    spread_element = "// %s",
    statement_block = "// %s",
  },
  twig = "{# %s #}",
  typescript = { "// %s", "/* %s */" }, -- langs can have multiple commentstrings
  vue = "<!-- %s -->",
  xaml = "<!-- %s -->",
}

---@param cs                            string
---@return string
local function normalize(cs)
  return vim.trim(cs:gsub("%s*%%s%s*", " %%s "))
end

---@param filetype                      string
---@return string[]
local function get_comments(filetype)
  local cc = native_get_option(filetype, "comments")
  if cc == vim.opt.comments._info.default or type(cc) ~= "string" then
    return {}
  end

  local comments = {} ---@type string[]
  local pieces = vim.split(cc, ",") or {} ---@type string[]
  for _, piece in ipairs(pieces) do
    local flags, str = piece:match("^(.-):(.*)$")
    if flags and not flags:match("[fsme]") then
      comments[#comments + 1] = str .. " %s"
    end
  end
  return comments
end

---@param spec                          table<string, string | string[]>
---@return string|string[]|nil
local function resolve_ts(spec)
  local line = vim.fn.getline(".")

  -- nvim_win_get_cursor returns (1,0) indexed tuple
  -- treesitter.get_node expects (0,0) indexed tuple
  local pos = vim.api.nvim_win_get_cursor(0)
  pos[1] = pos[1] - 1

  -- set position to the first non whitespace character
  local indent = line:match("^%s*()")
  if indent and pos[2] < indent - 1 then
    pos[2] = indent - 1
  end

  local ok, node = pcall(vim.treesitter.get_node, {
    ignore_injections = false, -- include injected languages
    pos = pos,
  })

  while ok and node do
    if spec[node:type()] then
      return spec[node:type()] -- found a commentstring for the current node
    end
    node = node:parent()
  end
end

-- Resolves the possible commentstrings for a given filetype in the current line
---@param filetype                      string
---@return string[]
local function resolve_commentstring(filetype)
  local lang = vim.treesitter.language.get_lang(filetype) or filetype
  local spec = language_map[lang] ---@type ghc.dressing.commentstring.ISpec

  local ret = {} ---@type string[]
  local have = {} ---@type table<string, boolean>

  ---@param comments                    string|string[]|nil
  local function add(comments)
    if type(comments) == "string" then
      comments = normalize(comments)
      if not have[comments] and comments ~= "" then
        have[comments] = true
        ret[#ret + 1] = comments
      end
    elseif type(comments) == "table" then
      add(comments[1]) -- add first one (used for commenting) and then add all the others (uncommenting)
      for _, v in pairs(comments) do
        add(v)
      end
    end
  end

  if type(spec) == "table" and not vim.islist(spec) then
    add(resolve_ts(spec))
  end

  add(spec) -- always add all found patterns
  ---@diagnostic disable-next-line: param-type-mismatch
  add(native_get_option(filetype, "commentstring")) -- always include the commentstring from the buffer
  add(get_comments(filetype))
  if #ret > 0 then
    local first = table.remove(ret, 1)
    table.sort(ret)
    table.insert(ret, 1, first)
  end
  return ret
end

---@param filetype                      string
---@return string
local function prettier_get_option(filetype)
  local patterns = resolve_commentstring(filetype) ---@type string[]
  local line = vim.fn.getline(".") ---@type string

  local cs = nil ---@type string|nil
  local n = math.huge ---@type integer
  for _, pattern in ipairs(patterns) do -- check all patterns to check if we want to uncomment
    local left, right = pattern:match("^%s*(.-)%s*%%s%s*(.-)%s*$") -- parse commentstring excluding whitespace
    if left and right then
      local l, m, r = line:match("^%s*" .. vim.pesc(left) .. "(%s*)(.-)(%s*)" .. vim.pesc(right) .. "%s*$")
      if m and #m < n then -- most commented line
        cs = vim.trim(left .. l .. "%s" .. r .. right) -- add correct whitespace to uncomment
        n = #m
      end
      if not cs then -- first pattern is the wanted commentstring
        cs = vim.trim(left .. " %s " .. right) -- add correct whitespace to comment
      end
    end
  end

  return cs or ""
end

---@param filetype                      string
---@param option                        string
---@return boolean|integer|string
---@diagnostic disable-next-line: duplicate-set-field
vim.filetype.get_option = function(filetype, option)
  if filetype == "comment" then
    filetype = vim.bo.filetype
  end

  if option == "commentstring" then
    return prettier_get_option(filetype)
  end

  return native_get_option(filetype, option)
end
