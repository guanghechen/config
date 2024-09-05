---@class guanghechen.plugin.IRawSpec
---@field public name                   string
---@field public main                   ?string

---@class guanghechen.plugin.ISpec
---@field public url                    string
---@field public branch                 string
---@field public name                   string
---@field public main                   ?string

---@class guanghechen.plugin.ISpecDetails : guanghechen.plugin.ISpec
---@field public cmd                    ?any
---@field public cond                   ?any
---@field public enabled                ?any
---@field public event                  ?any
---@field public lazy                   ?any

---@type guanghechen.plugin.IRawSpec[]
local raw_specs = {
  { name = "cmp-buffer" },
  { name = "cmp-nvim-lsp" },
  { name = "cmp-path" },
  { name = "copilot-cmp" },
  { name = "friendly-snippets" },
  { name = "nvim-treesitter-textobjects" },

  ------------------------------------------------------------------------------------------------

  { name = "conform.nvim", main = "conform" },
  { name = "copilot.lua", main = "copilot" },
  { name = "diffview.nvim", main = "diffview" },
  { name = "dressing.nvim", main = "dressing" },
  { name = "flash.nvim", main = "flash" },
  { name = "gitsigns.nvim", main = "gitsigns" },
  { name = "indent-blankline.nvim", main = "ibl" },
  { name = "mason.nvim", main = "mason" },
  { name = "mason-lspconfig.nvim", main = "mason-lspconfig" },
  { name = "mini.comment", main = "mini.comment" },
  { name = "mini.icons", main = "mini.icons" },
  { name = "mini.indentscope", main = "mini.indentscope" },
  { name = "mini.pairs", main = "mini.pairs" },
  { name = "mini.surround", main = "mini.surround" },
  { name = "neo-tree.nvim", main = "neo-tree" },
  { name = "noice.nvim", main = "noice" },
  { name = "nui.nvim", main = "nui" },
  { name = "nvim-cmp", main = "cmp" },
  { name = "nvim-colorizer.lua", main = "colorizer" },
  { name = "nvim-lspconfig", main = "lspconfig" },
  { name = "nvim-notify", main = "notify" },
  { name = "nvim-snippets", main = "snippets" },
  { name = "nvim-treesitter", main = "nvim-treesitter" },
  { name = "nvim-treesitter-context", main = "treesitter-context" },
  { name = "nvim-window-picker", main = "window-picker" },
  { name = "plenary.nvim", main = "plenary" },
  { name = "trouble.nvim", main = "trouble" },
  { name = "vim-illuminate", main = "illuminate" },
  { name = "which-key.nvim", main = "which-key" },
}

---@type guanghechen.plugin.ISpec[]
local specs = {}
for _, raw_spec in ipairs(raw_specs) do
  local url = "https://github.com/guanghechen/mirror.git" ---@type string
  local name = raw_spec.name ---@type string
  local main = raw_spec.main ---@type string
  ---@type guanghechen.plugin.ISpec
  local meta = {
    url = url,
    branch = "nvim@" .. name,
    name = name,
    main = main,
  }
  table.insert(specs, meta)
end

---extend specs------------------------------------------------------------------------------

local final_specs = {} ---@type guanghechen.plugin.ISpecDetails[]
for _, spec in ipairs(specs) do
  ---@type guanghechen.plugin.ISpecDetails
  local spec_basic = vim.tbl_deep_extend("force", {}, spec)
  table.insert(final_specs, spec_basic)
end

local no_details_module_names =
  { "cmp-buffer", "cmp-nvim-lsp", "cmp-path", "friendly-snippets", "mason-lspconfig.nvim", "nui.nvim", "plenary.nvim" }
for index = 1, #specs, 1 do
  local spec_basic = final_specs[index] ---@type guanghechen.plugin.ISpecDetails
  local spec_module_name = "guanghechen.plugin."
    .. spec_basic.name:gsub("%.nvim$", ""):gsub("%.lua$", ""):gsub("%.", "-"):gsub("%_", "-")
  local ok, spec_module = pcall(require, spec_module_name)
  if ok then
    local spec_details = vim.tbl_deep_extend("force", {}, spec_module)
    table.insert(final_specs, spec_details)

    spec_basic.cmd = spec_details.cmd
    spec_basic.cond = spec_details.cond
    spec_basic.enabled = spec_details.enabled
    spec_basic.event = spec_details.event
    spec_basic.lazy = spec_details.lazy
    spec_details.url = spec_basic.url
    spec_details.branch = spec_basic.branch
    spec_details.main = spec_basic.main
  elseif not eve.array.contains(no_details_module_names, spec_basic.name) then
    eve.reporter.error({
      from = "guanghechen.plugin.bootstrap",
      subject = "resolve plugin details",
      message = "Failed to resolve the details of plugin: " .. spec_basic.name,
    })
  end
end

return final_specs
