---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker" ---@type string

local position = "f_wl" ---@type eve.ux.nvimbar.PositionEnum
local c = eve.ux.nvimbar.component

---@alias eve.ux.picker.PaneEnum
---| "finder"
---| "preview"
---| "result"

---@alias eve.ux.picker.IOnDispose
---| fun(): nil

---@alias eve.ux.picker.IOnFocus
---| fun(self: eve.ux.Picker): nil

---@alias eve.ux.picker.IOnFinderChange
---| fun(self: eve.ux.Picker, bufnr: integer, input: string): nil

---@alias eve.ux.picker.IOnHide
---| fun(): nil

---@alias eve.ux.picker.IResultRender
---| fun(self: eve.ux.Picker, bufnr: integer, input: string): integer?, integer?

---@alias eve.ux.picker.IPreviewRender
---| fun(self: eve.ux.Picker, bufnr: integer, input: string): string

---@alias eve.ux.picker.ICheckKeymapDisabled
---| fun(self: eve.ux.Picker): boolean

---@class eve.ux.picker.IInternalFlagItem
---@field public type                   "enum"|"boolean"
---@field public desc                   string
---@field public callback_fn            string
---@field public callback               fun(): nil
---@field public snapshot               fun(): boolean, string

---@class eve.ux.picker.IFlagItem
---@field public type                   "enum"|"boolean"
---@field public desc                   string
---@field public callback               fun(self: eve.ux.Picker): nil
---@field public snapshot               fun(self: eve.ux.Picker): boolean, string

---@class eve.ux.picker.IInternalKeymap
---@field public mode                   eve.e.VimMode
---@field public key                    string
---@field public opts                   vim.keymap.set.Opts
---@field public callback               fun(self: eve.ux.Picker, bufnr: integer): nil

---@class eve.ux.picker.IKeymap
---@field public disabled               eve.ux.picker.ICheckKeymapDisabled|boolean|nil
---@field public modes                  eve.e.VimMode[]
---@field public aliases                string[]|nil
---@field public key                    string
---@field public callback               fun(self: eve.ux.Picker, bufnr: integer): nil
---
---@field public desc                   string
---@field public nowait                 boolean|nil
---@field public noremap                boolean|nil
---@field public silent                 boolean|nil

---@class eve.ux.picker.IWinOptions
---@field public number                 ?boolean
---@field public wrap                   ?boolean

---@class eve.ux.picker.IWinPosition
---@field public width                  integer
---@field public height                 integer
---@field public row                    integer
---@field public col                    integer

---@class eve.ux.picker.borders
---@field public finder                 string[]
---@field public finder_with_preview    string[]
---@field public finder_without_result  string[]
---@field public result                 string[]
---@field public result_with_preview    string[]
---@field public preview                string[]

---@class eve.ux.picker.highlights
---@field public finder                 string
---@field public result                 string
---@field public preview                string

---@class eve.ux.picker.keymaps_common

---@class eve.ux.picker.keymaps_finder
---@field public disables_on_singleline eve.ux.picker.IKeymap
---@field public disables_on_singleline_i eve.ux.picker.IKeymap
---@field public focus_down             eve.ux.picker.IKeymap
---@field public focus_left             eve.ux.picker.IKeymap
---@field public focus_right            eve.ux.picker.IKeymap
---@field public focus_up               eve.ux.picker.IKeymap
---@field public move_down              eve.ux.picker.IKeymap
---@field public move_down_singleline   eve.ux.picker.IKeymap
---@field public move_down2_singleline  eve.ux.picker.IKeymap
---@field public move_up                eve.ux.picker.IKeymap
---@field public move_up_singleline     eve.ux.picker.IKeymap
---@field public move_up2_singleline    eve.ux.picker.IKeymap

---@class eve.ux.picker.keymaps_result
---@field public disables               eve.ux.picker.IKeymap
---@field public edit_A                 eve.ux.picker.IKeymap
---@field public edit_a                 eve.ux.picker.IKeymap
---@field public edit_I                 eve.ux.picker.IKeymap
---@field public edit_i                 eve.ux.picker.IKeymap
---@field public edit_O                 eve.ux.picker.IKeymap
---@field public edit_o                 eve.ux.picker.IKeymap
---@field public focus                  eve.ux.picker.IKeymap
---@field public focus_down             eve.ux.picker.IKeymap
---@field public focus_left             eve.ux.picker.IKeymap
---@field public focus_right            eve.ux.picker.IKeymap
---@field public focus_up               eve.ux.picker.IKeymap

---@class eve.ux.picker.keymaps_preview
---@field public disables               eve.ux.picker.IKeymap
---@field public edit_A                 eve.ux.picker.IKeymap
---@field public edit_a                 eve.ux.picker.IKeymap
---@field public edit_I                 eve.ux.picker.IKeymap
---@field public edit_i                 eve.ux.picker.IKeymap
---@field public edit_O                 eve.ux.picker.IKeymap
---@field public edit_o                 eve.ux.picker.IKeymap
---@field public focus_down             eve.ux.picker.IKeymap
---@field public focus_left             eve.ux.picker.IKeymap
---@field public focus_right            eve.ux.picker.IKeymap
---@field public focus_up               eve.ux.picker.IKeymap

---@class eve.ux.picker.keymaps
---@field public common                 eve.ux.picker.keymaps_common
---@field public finder                 eve.ux.picker.keymaps_finder
---@field public result                 eve.ux.picker.keymaps_result
---@field public preview                eve.ux.picker.keymaps_preview

---@class eve.ux.picker.winopts
---@field public finder                 eve.ux.picker.IWinOptions
---@field public result                 eve.ux.picker.IWinOptions
---@field public preview                eve.ux.picker.IWinOptions

----------------------------------------------------------------------------------------------------

---@type eve.ux.picker.borders
local __borders__ = {
  -- stylua: ignore start
  finder                = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  finder_with_preview   = { "╭", "─", "┬", "│", "┤", "─", "├", "│" },
  finder_without_result = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  result                = { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  result_with_preview   = { "├", "─", "┤", "│", "┴", "─", "╰", "│" },
  preview               = { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
  -- stylua: ignore end
}

---@type eve.ux.picker.highlights
local __highlights__ = {
  finder = table.concat({
    "FloatBorder:FloatBorder",
    "FloatTitle:f_picker_finder_title",
    "Normal:f_picker_finder_normal",
  }, ","),
  result = table.concat({
    "Cursor:f_picker_result_current",
    "CursorColumn:f_picker_result_current",
    "CursorLine:f_picker_result_current",
    "CursorLineNr:f_picker_result_current",
    "FloatBorder:FloatBorder",
    "Normal:f_picker_result_normal",
  }, ","),
  preview = table.concat({
    "Cursor:f_picker_preview_current",
    "CursorColumn:f_picker_preview_current",
    "CursorLine:f_picker_preview_current",
    "CursorLineNr:f_picker_preview_current",
    "FloatBorder:FloatBorder",
    "FloatTitle:f_picker_preview_title",
    "Normal:f_picker_preview_normal",
  }, ","),
}

---@type eve.ux.picker.keymaps
local __keymaps__ = {
  common = {},
  finder = {
    disables_on_singleline = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "n", "v" },
      key = "o",
      aliases = { "O", "<enter>" },
      desc = "picker#finder: noop",
      callback = eve.std.fn.noop,
    },
    disables_on_singleline_i = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "i" },
      key = "<enter>",
      desc = "picker#finder: noop",
      callback = eve.std.fn.noop,
    },
    focus_down = {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "picker#finder: focus down",
      callback = function(self)
        self:__focus_pane__("result")
      end,
    },
    focus_left = {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "picker#finder: focus left",
      callback = function(self)
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("h")
          return
        end

        if self._preview_render ~= nil then
          self:__focus_pane__("preview")
          return
        end
      end,
    },
    focus_right = {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "picker#finder: focus right",
      callback = function(self)
        if self._preview_render ~= nil then
          self:__focus_pane__("preview")
          return
        end

        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("l")
          return
        end
      end,
    },
    focus_up = {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "picker#finder: focus up",
      callback = function(self)
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("k")
          return
        end

        self:__focus_pane__("result")
      end,
    },
    move_down = {
      modes = { "i", "n", "v" },
      key = "<C-j>",
      desc = "picker#finder: focus next item",
      callback = function(self)
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    move_down_singleline = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "n", "v" },
      key = "j",
      desc = "picker#finder: focus next item",
      callback = function(self)
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    move_down2_singleline = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "i", "n", "v" },
      key = "<Down>",
      desc = "picker#finder: focus next item",
      callback = function(self)
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(step)
      end,
    },
    move_first = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "n", "v" },
      key = "gg",
      desc = "picker#finder: focus first item",
      callback = function(self)
        self:__result_move_to__(1)
      end,
    },
    move_last = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "n", "v" },
      key = "G",
      desc = "picker#finder: focus last item",
      callback = function(self)
        local total = self._result_total:snapshot() ---@type integer
        self:__result_move_to__(total)
      end,
    },
    move_up = {
      modes = { "i", "n", "v" },
      key = "<C-k>",
      desc = "picker#finder: focus prev item",
      callback = function(self)
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    move_up_singleline = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "n", "v" },
      key = "k",
      desc = "picker#finder: focus prev item",
      callback = function(self)
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
    move_up2_singleline = {
      disabled = function(self)
        return self._finder_multiline
      end,
      modes = { "i", "n", "v" },
      key = "<Up>",
      desc = "picker#finder: focus prev item",
      callback = function(self)
        local step = vim.v.count1 or 1 ---@type integer
        self:__result_move_down__(-step)
      end,
    },
  },
  result = {
    disables = {
      modes = { "n", "v" },
      key = "d",
      aliases = { "dd", "X", "x" },
      desc = "picker#result: noop",
      callback = eve.std.fn.noop,
    },
    edit_A = {
      modes = { "n", "v" },
      key = "A",
      desc = "picker#result: back to edit (A)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("A", "n", false)
        end
      end,
    },
    edit_a = {
      modes = { "n", "v" },
      key = "a",
      desc = "picker#result: back to edit (a)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end,
    },
    edit_I = {
      modes = { "n", "v" },
      key = "I",
      desc = "picker#result: back to edit (I)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("I", "n", false)
        end
      end,
    },
    edit_i = {
      modes = { "n", "v" },
      key = "i",
      desc = "picker#result: back to edit (i)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("i", "n", false)
        end
      end,
    },
    edit_O = {
      modes = { "n", "v" },
      key = "O",
      desc = "picker#result: back to edit (O)",
      callback = function(self)
        self:__focus_pane__("finder")

        if self._finder_multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self._finder_winnr then
            vim.api.nvim_feedkeys("O", "n", false)
          end
        end
      end,
    },
    edit_o = {
      modes = { "n", "v" },
      key = "o",
      desc = "picker#result: back to edit (o)",
      callback = function(self)
        self:__focus_pane__("finder")

        if self._finder_multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self._finder_winnr then
            vim.api.nvim_feedkeys("o", "n", false)
          end
        end
      end,
    },
    focus = {
      disabled = true,
      modes = { "i", "n", "v" },
      key = "<LeftMouse>",
      desc = "picker#result: focus",
      callback = function(self)
        local cursor = vim.fn.getmousepos()
        local result_winnr = self._result_winnr ---@type integer|nil

        if cursor.winid == result_winnr then
          local lnum = cursor.line ---@type integer
          if lnum > 0 then
            self:__result_move_to__(lnum)
            return
          end
        end

        ---! fallback
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true), "n", false)
      end,
    },
    focus_down = {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "picker#result: focus down",
      callback = function(self)
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("j")
          return
        end

        self:__focus_pane__("finder")
      end,
    },
    focus_left = {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "picker#result: focus left",
      callback = function(self)
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("h")
          return
        end

        if self._preview_render ~= nil then
          self:__focus_pane__("preview")
          return
        end
      end,
    },
    focus_right = {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "picker#result: focus right",
      callback = function(self)
        if self._preview_render ~= nil then
          self:__focus_pane__("preview")
          return
        end

        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("l")
          return
        end
      end,
    },
    focus_up = {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "picker#result: focus up",
      callback = function(self)
        self:__focus_pane__("finder")
      end,
    },
  },
  preview = {
    disables = {
      modes = { "n", "v" },
      key = "d",
      aliases = { "dd", "X", "x" },
      desc = "picker#preview: noop",
      callback = eve.std.fn.noop,
    },
    edit_A = {
      modes = { "n", "v" },
      key = "A",
      desc = "picker#preview: back to edit (A)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("A", "n", false)
        end
      end,
    },
    edit_a = {
      modes = { "n", "v" },
      key = "a",
      desc = "picker#preview: back to edit (a)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("a", "n", false)
        end
      end,
    },
    edit_I = {
      modes = { "n", "v" },
      key = "I",
      desc = "picker#preview: back to edit (I)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("I", "n", false)
        end
      end,
    },
    edit_i = {
      modes = { "n", "v" },
      key = "i",
      desc = "picker#preview: back to edit (i)",
      callback = function(self)
        self:__focus_pane__("finder")

        local winnr = vim.api.nvim_get_current_win() ---@type integer
        if winnr == self._finder_winnr then
          vim.api.nvim_feedkeys("i", "n", false)
        end
      end,
    },
    edit_O = {
      modes = { "n", "v" },
      key = "O",
      desc = "picker#preview: back to edit (O)",
      callback = function(self)
        self:__focus_pane__("finder")

        if self._finder_multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self._finder_winnr then
            vim.api.nvim_feedkeys("O", "n", false)
          end
        end
      end,
    },
    edit_o = {
      modes = { "n", "v" },
      key = "o",
      desc = "picker#preview: back to edit (o)",
      callback = function(self)
        self:__focus_pane__("finder")

        if self._finder_multiline then
          local winnr = vim.api.nvim_get_current_win() ---@type integer
          if winnr == self._finder_winnr then
            vim.api.nvim_feedkeys("o", "n", false)
          end
        end
      end,
    },
    focus_down = {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "picker#preview: focus down",
      callback = function()
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("j")
          return
        end
      end,
    },
    focus_left = {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "picker#result: focus left",
      callback = function(self)
        local pane_focused = self._pane_last_focused == "result" and "result" or "finder" ---@type eve.ux.picker.PaneEnum
        self:__focus_pane__(pane_focused)
      end,
    },
    focus_right = {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "picker#result: focus right",
      callback = function(self)
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("l")
          return
        end

        local pane_focused = self._pane_last_focused == "result" and "result" or "finder" ---@type eve.ux.picker.PaneEnum
        self:__focus_pane__(pane_focused)
      end,
    },
    focus_up = {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "picker#preview: focus up",
      callback = function()
        if eve.env.IS_TMUX and not eve.status.tmux_zen_mode:snapshot() then
          eve.tmux.change_pane("k")
          return
        end
      end,
    },
  },
}

---@type eve.ux.picker.winopts
local __winopts__ = {
  finder = {
    number = false,
    wrap = false,
  },
  result = {
    number = false,
    wrap = false,
  },
  preview = {
    number = true,
    wrap = false,
  },
}

----------------------------------------------------------------------------------------------------

---@class eve.ux.IPickerProps
---@field public uuid                   ?string
---@field public name                   string
---@field public nsnr                   ?integer
---@field public permanent              boolean
---@field public flags                  ?eve.ux.picker.IFlagItem[]
---@field public flags_start_index      ?0|1
---
---@field public finder_input           ?string
---@field public finder_keymaps         ?eve.ux.picker.IKeymap[]
---@field public finder_multiline       ?boolean
---@field public finder_title           string
---@field public finder_win_opts        ?eve.ux.picker.IWinOptions
---
---@field public result_keymaps         ?eve.ux.picker.IKeymap[]
---@field public result_render          eve.ux.picker.IResultRender
---@field public result_win_opts        ?eve.ux.picker.IWinOptions
---
---@field public preview_keymaps        ?eve.ux.picker.IKeymap[]
---@field public preview_render         ?eve.ux.picker.IResultRender
---@field public preview_win_opts       ?eve.ux.picker.IWinOptions
---
---@field public on_dispose             ?eve.ux.picker.IOnDispose
---@field public on_focus               ?eve.ux.picker.IOnFocus
---@field public on_finder_change       eve.ux.picker.IOnFinderChange
---@field public on_hide                ?eve.ux.picker.IOnHide

---@class eve.ux.Picker : eve.t.ux.IWidget
---@field public uuid                   string
---@field public name                   string
---@field public nsnr                   integer
---@field public permanent              boolean
---
---@field protected _disposed           boolean
---@field protected _augroup_CursorMoved integer
---@field protected _pane_focused       eve.ux.picker.PaneEnum
---@field protected _pane_last_focused  eve.ux.picker.PaneEnum
---@field protected _flags              eve.ux.picker.IInternalFlagItem[]
---@field protected _flags_start_index  0|1
---
---@field protected _scheduler_preview  eve.std.collection.Scheduler|nil
---@field protected _scheduler_result   eve.std.collection.Scheduler
---
---@field protected _finder_bufnr       integer|nil
---@field protected _finder_winnr       integer|nil
---@field protected _finder_keymaps     eve.ux.picker.IInternalKeymap[]
---@field protected _finder_title       string
---@field protected _finder_winopts     eve.ux.picker.IWinOptions
---@field protected _finder_input       eve.std.collection.Observable
---@field protected _finder_line_count  eve.std.collection.Observable
---@field protected _finder_multiline   boolean
---
---@field protected _result_bufnr       integer|nil
---@field protected _result_winnr       integer|nil
---@field protected _result_keymaps     eve.ux.picker.IInternalKeymap[]
---@field protected _result_winopts     eve.ux.picker.IWinOptions
---@field protected _result_lnum        eve.std.collection.Observable
---@field protected _result_total       eve.std.collection.Observable
---@field protected _result_nvimbar     eve.ux.nvimbar.Nvimbar
---@field protected _result_render      eve.ux.picker.IResultRender
---
---@field protected _preview_bufnr      integer|nil
---@field protected _preview_winnr      integer|nil
---@field protected _preview_keymaps    eve.ux.picker.IInternalKeymap[]
---@field protected _preview_title      string|nil
---@field protected _preview_winopts    eve.ux.picker.IWinOptions
---@field protected _preview_render     eve.ux.picker.IPreviewRender|nil
---
---@field protected _on_dispose         eve.ux.picker.IOnDispose
---@field protected _on_focus           eve.ux.picker.IOnFocus
---@field protected _on_finder_change   eve.ux.picker.IOnFinderChange
---@field protected _on_hide            eve.ux.picker.IOnHide
local M = {}
M.__index = M

local NSNR_DEFAULT = vim.api.nvim_create_namespace("ux_view_picker") ---@type integer

---@param props                         eve.ux.IPickerProps
---@return eve.ux.Picker
function M.new(props)
  local uuid = props.uuid or eve.oxi.uuid() ---@type string
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local permanent = not not props.permanent ---@type boolean
  local flags = {} ---@type eve.ux.picker.IInternalFlagItem[]
  local flags_start_index = props.flags_start_index == 0 and 0 or 1 ---@type 0|1
  local augroup_CursorMoved = eve.nvim.augroup(string.format("picker:CursorMoved%s#%s", name, uuid))

  local initial_input = props.finder_input or "" ---@type string
  local initial_input_lines = vim.split(initial_input, "\n", { plain = true }) ---@type string[]
  local finder_input = eve.std.Observable.from_value(initial_input) ---@type eve.std.collection.Observable
  local finder_keymaps = props.finder_keymaps or {} ---@type eve.ux.picker.IKeymap[]
  local finder_count = eve.std.Observable.from_value(#initial_input_lines) ---@type eve.std.collection.Observable
  local finder_multiline = not not props.finder_multiline ---@type boolean
  local finder_title = string.format(" %s ", vim.trim(props.finder_title)) ---@type string
  local finder_winopts = vim.tbl_deep_extend("force", {}, __winopts__.finder, props.finder_win_opts or {}) ---@type eve.ux.picker.IWinOptions

  local result_keymaps = props.result_keymaps or {} ---@type eve.ux.picker.IKeymap[]
  local result_lnum = eve.std.Observable.from_value(0) ---@type eve.std.collection.Observable
  local result_total = eve.std.Observable.from_value(0) ---@type eve.std.collection.Observable
  local result_render = props.result_render ---@type eve.ux.picker.IResultRender
  local result_winopts = vim.tbl_deep_extend("force", {}, __winopts__.result, props.result_win_opts or {}) ---@type eve.ux.picker.IWinOptions

  local preview_keymaps = props.preview_keymaps or {} ---@type eve.ux.picker.IKeymap[]
  local preview_render = props.preview_render ---@type eve.ux.picker.IPreviewRender|nil
  local preview_winopts = vim.tbl_deep_extend("force", {}, __winopts__.preview, props.preview_win_opts or {}) ---@type eve.ux.picker.IWinOptions

  local on_dispose = props.on_dispose or eve.std.fn.noop ---@type eve.ux.picker.IOnDispose
  local on_focus = props.on_focus or eve.std.fn.noop ---@type eve.ux.picker.IOnFocus
  local on_finder_change = props.on_finder_change ---@type eve.ux.picker.IOnFinderChange
  local on_hide = props.on_hide or eve.std.fn.noop ---@type eve.ux.picker.IOnHide

  local self = setmetatable({}, M)

  if props.flags ~= nil and #props.flags > 0 then
    for _, flag in ipairs(props.flags) do
      local raw_callback = flag.callback ---@type fun(self: eve.ux.Picker): nil
      local raw_snapshot = flag.snapshot ---@type fun(self: eve.ux.Picker): boolean, string

      ---@return nil
      local function callback()
        raw_callback(self)
      end

      ---@return boolean
      ---@return string
      local function snapshot()
        return raw_snapshot(self)
      end

      local callback_fn = eve.G.register_anonymous_fn(callback) or "eve.G.noop" ---@type string

      ---@type eve.ux.picker.IInternalFlagItem
      local item = {
        type = flag.type,
        desc = flag.desc,
        callback = callback,
        callback_fn = callback_fn,
        snapshot = snapshot,
      }
      flags[#flags + 1] = item
    end
  end

  self.uuid = uuid
  self.name = name
  self.nsnr = nsnr
  self.permanent = permanent
  self._flags = flags
  self._flags_start_index = flags_start_index

  self._disposed = false ---@type boolean
  self._augroup_CursorMoved = augroup_CursorMoved
  self._pane_focused = "finder" ---@type eve.ux.picker.PaneEnum
  self._pane_last_focused = "finder" ---@type eve.ux.picker.PaneEnum

  self._finder_bufnr = nil
  self._finder_winnr = nil
  self._finder_title = finder_title
  self._finder_winopts = finder_winopts
  self._finder_input = finder_input
  self._finder_line_count = finder_count
  self._finder_multiline = finder_multiline

  self._result_bufnr = nil
  self._result_winnr = nil
  self._result_winopts = result_winopts
  self._result_lnum = result_lnum
  self._result_total = result_total
  self._result_render = result_render

  self._preview_bufnr = nil
  self._preview_winnr = nil
  self._preview_title = nil
  self._preview_winopts = preview_winopts
  self._preview_render = preview_render

  self._on_dispose = on_dispose ---@type eve.ux.picker.IOnDispose
  self._on_focus = on_focus ---@type eve.ux.picker.IOnFocus
  self._on_finder_change = on_finder_change ---@type eve.ux.picker.IOnFinderChange
  self._on_hide = on_hide ---@type eve.ux.picker.IOnHide

  self._finder_keymaps = self:__resolve_finder__keymaps__(finder_keymaps)
  self._result_keymaps = self:__resolve_result__keymaps__(result_keymaps)
  self._preview_keymaps = self:__resolve_preview__keymaps__(preview_keymaps)

  self._result_nvimbar = eve.ux.nvimbar.Nvimbar
    .new({
      name = string.format("picker:result:%s", name),
      comp_sep = "",
      comp_sep_hlname = "f_wl_picker",
      comp_sep_hlname_active = "f_wl_picker",
      delay = 128,
      silent = eve.std.fn.falsy,
      get_max_width = function()
        local winnr = self._result_winnr ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
        return 0
      end,
      get_preset_context = function()
        local winnr = self._result_winnr ---@type integer|nil
        return { winnr = winnr }
      end,
      is_active = function()
        local winnr = self._result_winnr ---@type integer|nil
        return winnr == vim.api.nvim_get_current_win()
      end,
      on_fulfilled = function(result)
        local winnr = self._result_winnr ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          vim.wo[winnr].winbar = result
        end
      end,
    })
    :place("left", c.picker.result_flags(position, flags, flags_start_index), 100)
    :place("right", c.picker.result_pos(position, result_lnum, result_total), 100)

  if preview_render ~= nil then
    self._scheduler_preview = eve.std.Scheduler.new({
      name = string.format("picker:preview:%s", name),
      mode = "debounce",
      delay = 256,
      timeout = 0,
      silent = eve.std.fn.falsy,
      value = eve.std.Observable.from_value(true),
      task = function(scheduler)
        local bufnr = self:get_preview_bufnr() ---@type integer|nil
        if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        vim.bo[bufnr].modifiable = true
        vim.bo[bufnr].readonly = false

        local input = finder_input:snapshot() ---@type string
        local ok, preview_title = pcall(preview_render, self, bufnr, input) ---@type boolean, string|nil
        if not ok then
          eve.reporter.error({
            from = __module_name__,
            subject = scheduler.name,
            message = "Failed to render preview",
            details = {
              bufnr = bufnr,
            },
          })
        else
          if preview_title ~= nil then
            self._preview_title = string.format(" %s ", vim.trim(preview_title))
          end
        end

        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].readonly = true
      end,
    })
  end

  ---@type eve.std.collection.Scheduler
  self._scheduler_result = eve.std.Scheduler.new({
    name = string.format("picker:result:%s", name),
    mode = "debounce",
    delay = 128,
    timeout = 0,
    silent = eve.std.fn.falsy,
    value = eve.std.Observable.from_value(true),
    task = function(scheduler)
      local bufnr = self:get_result_bufnr() ---@type integer|nil
      if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.bo[bufnr].modifiable = true
      vim.bo[bufnr].readonly = false

      local input = finder_input:snapshot() ---@type string
      local ok, lnum, lnum_present = pcall(result_render, self, bufnr, input) ---@type boolean, integer|nil, integer|nil
      if not ok then
        eve.reporter.error({
          from = __module_name__,
          subject = scheduler.name,
          message = "Failed to render result",
          details = {
            bufnr = bufnr,
          },
        })
        lnum = 1
      end

      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].readonly = true

      local total = vim.api.nvim_buf_line_count(bufnr) ---@type integer
      result_total:next(total)

      lnum = lnum or result_lnum:snapshot() ---@type integer
      lnum = math.min(total, math.max(total > 0 and 1 or 0, lnum)) ---@type integer
      result_lnum:next(lnum)

      vim.fn.sign_unplace("", { buffer = bufnr, id = bufnr })
      if lnum_present ~= nil then
        vim.fn.sign_place(bufnr, "", eve.var.sign.PICKER_RESULT_PRESENT, bufnr, { lnum = lnum, priority = 10 })
      end

      if self._scheduler_preview ~= nil then
        self._scheduler_preview:schedule()
      end
    end,
  })

  result_lnum:subscribe(
    eve.std.Subscriber.new({
      on_next = function(lnum)
        self._result_nvimbar:render()
        if self._scheduler_preview ~= nil then
          self._scheduler_preview:schedule()
        end
        vim.schedule(function()
          local winnr = self._result_winnr ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            pcall(vim.api.nvim_win_set_cursor, winnr, { lnum, 0 })
          end
        end)
      end,
    }),
    true
  )

  result_total:subscribe(
    eve.std.Subscriber.new({
      on_next = function(total)
        self._result_nvimbar:render()
        if self._scheduler_preview ~= nil then
          self._scheduler_preview:schedule()
        end
        vim.schedule(function()
          local winnr = self._result_winnr ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            vim.wo[winnr].cursorline = total > 0
          end
        end)
      end,
    }),
    false
  )

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup_CursorMoved,
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      if winnr == self._result_winnr then
        local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
        local row = cursor[1] ---@type integer
        if cursor[2] ~= 0 then
          vim.api.nvim_win_set_cursor(winnr, { row, 0 })
        end
        result_lnum:next(row)
      end
    end,
  })

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local augroup_CursorMoved = self._augroup_CursorMoved ---@type integer
  local on_dispose = self._on_dispose ---@type eve.ux.picker.IOnDispose

  self._augroup_CursorMoved = nil
  self._pane_focused = nil
  self._pane_last_focused = nil
  self._flags = nil
  self._flags_start_index = nil

  self._scheduler_result:dispose()
  if self._scheduler_preview then
    self._scheduler_preview:dispose()
  end
  self._scheduler_result = nil
  self._scheduler_preview = nil

  local finder_winnr = self._finder_winnr ---@type integer|nil
  local finder_bufnr = self._finder_bufnr ---@type integer|nil
  local result_winnr = self._result_winnr ---@type integer|nil
  local result_bufnr = self._result_bufnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil
  local preview_bufnr = self._preview_bufnr ---@type integer|nil
  self._finder_winnr = nil
  self._finder_bufnr = nil
  self._result_winnr = nil
  self._result_bufnr = nil
  self._preview_winnr = nil
  self._preview_bufnr = nil
  eve.win.close(finder_winnr)
  eve.buf.close(finder_bufnr)
  eve.win.close(result_winnr)
  eve.buf.close(result_bufnr)
  eve.win.close(preview_winnr)
  eve.buf.close(preview_bufnr)

  self._finder_input:dispose()
  self._finder_line_count:dispose()
  self._result_total:dispose()
  self._result_lnum:dispose()
  self._result_nvimbar:dispose()

  self._finder_bufnr = nil
  self._finder_winnr = nil
  self._finder_keymaps = nil
  self._finder_title = nil
  self._finder_winopts = nil
  self._finder_input = nil
  self._finder_line_count = nil
  self._finder_multiline = nil

  self._result_bufnr = nil
  self._result_winnr = nil
  self._result_keymaps = nil
  self._result_winopts = nil
  self._result_lnum = nil
  self._result_total = nil
  self._result_nvimbar = nil
  self._result_render = nil

  self._preview_bufnr = nil
  self._preview_winnr = nil
  self._preview_keymaps = nil
  self._preview_title = nil
  self._preview_winopts = nil
  self._preview_render = nil

  self._on_dispose = nil
  self._on_finder_change = nil

  pcall(vim.api.nvim_clear_autocmds, { group = augroup_CursorMoved })
  vim.schedule(function()
    pcall(on_dispose)
  end)
end

---@return nil
function M:close()
  if self._disposed then
    return
  end

  if not self.permanent then
    self:dispose()
    return
  end

  self:hide()
end

---@param pane                         eve.ux.picker.PaneEnum|nil
---@return nil
function M:focus(pane)
  self:__health__()
  eve.widget.push(self)

  local has_new_created = self:__create_wins__()
  local pane_focused = has_new_created and "finder" or self._pane_focused ---@type eve.ux.picker.PaneEnum
  self:__focus_pane__(pane or pane_focused)

  vim.schedule(function()
    pcall(self._on_focus, self)
  end)
end

---@return nil
function M:hide()
  if self._disposed then
    return
  end

  local finder_winnr = self._finder_winnr ---@type integer|nil
  local result_winnr = self._result_winnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil
  self._finder_winnr = nil
  self._preview_winnr = nil
  self._result_winnr = nil
  eve.win.close(finder_winnr)
  eve.win.close(preview_winnr)
  eve.win.close(result_winnr)

  vim.schedule(function()
    pcall(self._on_hide)
  end)
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  return winnr == self._finder_winnr or winnr == self._result_winnr or winnr == self._preview_winnr
end

---@return boolean
function M:isvisible()
  if self._disposed then
    return false
  end

  local finder_winnr = self._finder_winnr ---@type integer|nil
  if finder_winnr ~= nil and vim.api.nvim_win_is_valid(finder_winnr) then
    return true
  end

  local result_winnr = self._result_winnr ---@type integer|nil
  if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
    return true
  end

  local preview_winnr = self._preview_winnr ---@type integer|nil
  if preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr) then
    return true
  end

  return false
end

---@return integer|nil
function M:get_finder_bufnr()
  self:__health__()

  local bufnr = self._finder_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._finder_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_finder_winnr()
  self:__health__()

  local winnr = self._finder_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._finder_winnr = nil
    return nil
  end
  return winnr
end

---@return integer|nil
function M:get_result_bufnr()
  self:__health__()

  local bufnr = self._result_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._result_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer
function M:get_result_lnum()
  self:__health__()
  return self._result_lnum:snapshot()
end

---@return integer|nil
function M:get_result_winnr()
  self:__health__()

  local winnr = self._result_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._result_winnr = nil
    return nil
  end
  return winnr
end

---@return integer|nil
function M:get_preview_bufnr()
  self:__health__()

  local bufnr = self._preview_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    self._preview_bufnr = nil
    return nil
  end
  return bufnr
end

---@return integer|nil
function M:get_preview_winnr()
  self:__health__()

  local winnr = self._preview_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self._preview_winnr = nil
    return nil
  end
  return winnr
end

---@return nil
function M:mark_result_dirty()
  self:__health__()
  self._scheduler_result:schedule()
end

---@return nil
function M:mark_result_flags_dirty()
  self:__health__()
  self._result_nvimbar:render()
end

---@return nil
function M:resize()
  self:__health__()

  if not self:isvisible() then
    return
  end

  local has_new_created, finder_winnr, result_winnr, preview_winnr = self:__create_wins__() ---@type boolean, integer, integer, integer|nil
  if has_new_created then
    self:__focus_pane__("finder")
    return
  end

  local finder_position, result_position, preview_position = self:__resize__() ---@type eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition|nil

  local finder_wincfg = vim.api.nvim_win_get_config(finder_winnr) ---@type vim.api.keyset.win_config
  finder_wincfg.row = finder_position.row
  finder_wincfg.col = finder_position.col
  finder_wincfg.width = finder_position.width
  finder_wincfg.height = finder_position.height
  vim.api.nvim_win_set_config(finder_winnr, finder_wincfg)

  local result_wincfg = vim.api.nvim_win_get_config(result_winnr) ---@type vim.api.keyset.win_config
  result_wincfg.row = result_position.row
  result_wincfg.col = result_position.col
  result_wincfg.width = result_position.width
  result_wincfg.height = result_position.height
  vim.api.nvim_win_set_config(result_winnr, result_wincfg)
  vim.wo[result_winnr].winbar = self._result_nvimbar:snapshot()

  if preview_winnr ~= nil and preview_position ~= nil then
    local preview_wincfg = vim.api.nvim_win_get_config(preview_winnr) ---@type vim.api.keyset.win_config
    preview_wincfg.row = preview_position.row
    preview_wincfg.col = preview_position.col
    preview_wincfg.width = preview_position.width
    preview_wincfg.height = preview_position.height
    vim.api.nvim_win_set_config(preview_winnr, preview_wincfg)
  end
end

---@param content                       string
---@return nil
function M:set_finder_content(content)
  self:__health__()

  if content == self._finder_input:snapshot() then
    return
  end

  local finder_bufnr = self._finder_bufnr ---@type integer|nil
  if finder_bufnr == nil or not vim.api.nvim_buf_is_valid(finder_bufnr) then
    return
  end

  local lines = self._finder_multiline and { content } or vim.split(content, "\n", { plain = true }) ---@type  string[]
  if #lines < 1 then
    lines = { "" } ---@type string[]
  end
  vim.api.nvim_buf_set_lines(finder_bufnr, 0, -1, false, lines)
  self._finder_input:next(content)
  self._finder_line_count:next(#lines)
  self:__set_finder_prompt_sign__(finder_bufnr)
end

---@param title                         string
---@return nil
function M:set_finder_title(title)
  self:__health__()
  self._finder_title = string.format(" %s ", vim.trim(title)) ---@type string

  local finder_winnr = self._finder_winnr ---@type integer|nil
  if finder_winnr ~= nil and vim.api.nvim_win_is_valid(finder_winnr) then
    local wincfg = vim.api.nvim_win_get_config(finder_winnr) ---@type vim.api.keyset.win_config
    wincfg.title = self._finder_title
    vim.api.nvim_win_set_config(finder_winnr, wincfg)
  else
    self:__create_wins__()
  end
end

---@param title                         string
---@return nil
function M:set_preview_title(title)
  self:__health__()
  self._preview_title = string.format(" %s ", vim.trim(title)) ---@type string

  local should_preview_show = self:__should_show_preview__() ---@type boolean
  if should_preview_show then
    local preview_winnr = self._preview_winnr ---@type integer|nil
    if preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr) then
      local wincfg = vim.api.nvim_win_get_config(preview_winnr) ---@type vim.api.keyset.win_config
      wincfg.title = self._preview_title
      vim.api.nvim_win_set_config(preview_winnr, wincfg)
    else
      self:__create_wins__()
    end
  end
end

---@param lnum                          integer
---@return nil
function M:set_result_lnum(lnum)
  self:__health__()

  local total = self._result_total:snapshot() ---@type integer
  lnum = math.min(total, math.max(0, lnum)) ---@type integer
  self._result_lnum:next(lnum)
end

---@protected
---@return integer
---@return integer
---@return integer|nil
function M:__create_bufs__()
  local finder_bufnr = self._finder_bufnr ---@type integer|nil
  local result_bufnr = self._result_bufnr ---@type integer|nil
  local preview_bufnr = self._preview_bufnr ---@type integer|nil
  local has_preview = self._preview_render ~= nil ---@type boolean

  if finder_bufnr == nil or not vim.api.nvim_buf_is_valid(finder_bufnr) then
    finder_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._finder_bufnr = finder_bufnr

    vim.b[finder_bufnr].miniindentscope_disable = true
    vim.b[finder_bufnr].miniai_disable = true
    vim.b[finder_bufnr].minihipatterns_disable = true
    vim.bo[finder_bufnr].buflisted = false
    vim.bo[finder_bufnr].buftype = "nofile"
    vim.bo[finder_bufnr].filetype = eve.filetype.UX_PICKER_FINDER
    vim.bo[finder_bufnr].swapfile = false

    local keymaps = self._finder_keymaps ---@type eve.ux.picker.IInternalKeymap[]
    for _, keymap in ipairs(keymaps) do
      ---@return nil
      local function callback()
        keymap.callback(self, finder_bufnr)
      end

      ---@type vim.keymap.set.Opts
      local opts = {
        buffer = finder_bufnr,
        desc = keymap.opts.desc,
        nowait = keymap.opts.nowait,
        noremap = keymap.opts.noremap,
        silent = keymap.opts.silent,
      }
      vim.keymap.set(keymap.mode, keymap.key, callback, opts)
    end

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      buffer = finder_bufnr,
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(finder_bufnr, 0, -1, false) ---@type string[]
        local content = table.concat(lines, "\n") ---@type string
        self._finder_input:next(content)
        self._finder_line_count:next(#lines)
        self._on_finder_change(self, finder_bufnr, content)
        self:__set_finder_prompt_sign__(finder_bufnr)
      end,
    })

    self:__set_finder_prompt_sign__(finder_bufnr)
  end

  if result_bufnr == nil or not vim.api.nvim_buf_is_valid(result_bufnr) then
    result_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._result_bufnr = result_bufnr

    local keymaps = self._result_keymaps ---@type eve.ux.picker.IInternalKeymap[]
    for _, keymap in ipairs(keymaps) do
      ---@return nil
      local function callback()
        keymap.callback(self, result_bufnr)
      end

      ---@type vim.keymap.set.Opts
      local opts = {
        buffer = result_bufnr,
        desc = keymap.opts.desc,
        nowait = keymap.opts.nowait,
        noremap = keymap.opts.noremap,
        silent = keymap.opts.silent,
      }
      vim.keymap.set(keymap.mode, keymap.key, callback, opts)
    end

    vim.b[result_bufnr].miniindentscope_disable = true
    vim.b[result_bufnr].miniai_disable = true
    vim.b[result_bufnr].minihipatterns_disable = true
    vim.bo[result_bufnr].buflisted = false
    vim.bo[result_bufnr].buftype = "nofile"
    vim.bo[result_bufnr].filetype = eve.filetype.UX_PICKER_RESULT
    vim.bo[result_bufnr].swapfile = false
    vim.bo[result_bufnr].modifiable = false
    vim.bo[result_bufnr].readonly = true

    self._scheduler_result:schedule({ immediate = true })
  end

  if has_preview then
    if preview_bufnr == nil or not vim.api.nvim_buf_is_valid(preview_bufnr) then
      preview_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      self._preview_bufnr = preview_bufnr

      local keymaps = self._preview_keymaps ---@type eve.ux.picker.IInternalKeymap[]
      for _, keymap in ipairs(keymaps) do
        ---@return nil
        local function callback()
          keymap.callback(self, result_bufnr)
        end

        ---@type vim.keymap.set.Opts
        local opts = {
          buffer = preview_bufnr,
          desc = keymap.opts.desc,
          nowait = keymap.opts.nowait,
          noremap = keymap.opts.noremap,
          silent = keymap.opts.silent,
        }
        vim.keymap.set(keymap.mode, keymap.key, callback, opts)
      end

      vim.b[preview_bufnr].miniindentscope_disable = true
      vim.b[preview_bufnr].miniai_disable = true
      vim.b[preview_bufnr].minihipatterns_disable = true
      vim.bo[preview_bufnr].buflisted = false
      vim.bo[preview_bufnr].buftype = "nofile"
      vim.bo[preview_bufnr].filetype = eve.filetype.UX_PICKER_PREVIEW
      vim.bo[preview_bufnr].swapfile = false
      vim.bo[preview_bufnr].modifiable = false
      vim.bo[preview_bufnr].readonly = true
    end

    self._scheduler_preview:schedule({ immediate = true })
  else
    self._preview_bufnr = nil
    if preview_bufnr ~= nil and vim.api.nvim_buf_is_valid(preview_bufnr) then
      vim.api.nvim_buf_delete(preview_bufnr, { force = true })
    end
  end

  return finder_bufnr, result_bufnr, preview_bufnr
end

---@protected
---@return boolean
---@return integer
---@return integer
---@return integer|nil
function M:__create_wins__()
  local should_show_preview = self:__should_show_preview__() ---@type boolean
  local finder_winnr = self._finder_winnr ---@type integer|nil
  local result_winnr = self._result_winnr ---@type integer|nil
  local preview_winnr = self._preview_winnr ---@type integer|nil

  if finder_winnr ~= nil and not vim.api.nvim_win_is_valid(finder_winnr) then
    self._finder_winnr = nil
    finder_winnr = nil
  end

  if result_winnr ~= nil and not vim.api.nvim_win_is_valid(result_winnr) then
    self._result_winnr = nil
    result_winnr = nil
  end

  if preview_winnr ~= nil and not vim.api.nvim_win_is_valid(preview_winnr) then
    self._preview_winnr = nil
    preview_winnr = nil
  end

  if preview_winnr ~= nil and not should_show_preview then
    self._preview_winnr = nil
    eve.win.close(preview_winnr)
    preview_winnr = nil
  end

  if finder_winnr ~= nil and result_winnr ~= nil and (preview_winnr ~= nil or not should_show_preview) then
    return false, finder_winnr, result_winnr, preview_winnr
  end

  local winblend = eve.state.theme.get_float_winblend() ---@type integer
  local finder_bufnr, result_bufnr, preview_bufnr = self:__create_bufs__() ---@type integer, integer, integer|nil
  local finder_position, result_position, preview_position = self:__resize__() ---@type eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition, eve.ux.picker.IWinPosition|nil

  local finder_wincfg = {
    relative = "editor",
    row = finder_position.row,
    col = finder_position.col,
    width = finder_position.width,
    height = finder_position.height,
    border = __borders__.finder,
    style = "minimal",
    focusable = true,
    title = self._finder_title,
    title_pos = "center",
  }
  if finder_winnr == nil then
    finder_wincfg.noautocmd = true
    finder_winnr = vim.api.nvim_open_win(finder_bufnr, false, finder_wincfg)
    self._finder_winnr = finder_winnr

    eve.win.set_type(finder_winnr, eve.win.Types.PICKER_FINDER)

    local winopts = self._finder_winopts ---@type eve.ux.picker.IWinOptions
    vim.wo[finder_winnr].number = winopts.number
    vim.wo[finder_winnr].relativenumber = false
    vim.wo[finder_winnr].signcolumn = "yes"
    vim.wo[finder_winnr].spell = false
    vim.wo[finder_winnr].winblend = winblend
    vim.wo[finder_winnr].winfixbuf = true
    vim.wo[finder_winnr].winhighlight = __highlights__.finder
    vim.wo[finder_winnr].wrap = winopts.wrap
  else
    vim.api.nvim_win_set_config(finder_winnr, finder_wincfg)
    vim.api.nvim_win_set_buf(finder_winnr, finder_bufnr)
  end
  vim.wo[finder_winnr].cursorline = false

  local result_wincfg = {
    relative = "editor",
    row = result_position.row,
    col = result_position.col,
    width = result_position.width,
    height = result_position.height,
    border = should_show_preview and __borders__.result_with_preview or __borders__.result,
    style = "minimal",
    focusable = true,
  }
  if result_winnr == nil then
    result_wincfg.noautocmd = true
    result_winnr = vim.api.nvim_open_win(result_bufnr, false, result_wincfg)
    self._result_winnr = result_winnr

    eve.win.set_type(result_winnr, eve.win.Types.PICKER_RESULT)

    local winopts = self._result_winopts ---@type eve.ux.picker.IWinOptions
    vim.wo[result_winnr].number = winopts.number
    vim.wo[result_winnr].signcolumn = "yes"
    vim.wo[result_winnr].spell = false
    vim.wo[result_winnr].winblend = winblend
    vim.wo[result_winnr].winfixbuf = true
    vim.wo[result_winnr].winhighlight = __highlights__.result
    vim.wo[result_winnr].wrap = winopts.wrap

    local lnum = self._result_lnum:snapshot() ---@type integer
    pcall(vim.api.nvim_win_set_cursor, result_winnr, { lnum, 0 })
  else
    vim.api.nvim_win_set_config(result_winnr, result_wincfg)

    vim.wo[result_winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(result_winnr, result_bufnr)
    vim.wo[result_winnr].winfixbuf = true
  end
  vim.wo[result_winnr].cursorline = self._result_total:snapshot() > 0
  vim.wo[result_winnr].winbar = self._result_nvimbar:snapshot()

  if should_show_preview then
    ---@cast preview_bufnr              integer
    ---@cast preview_position           eve.ux.picker.IWinPosition

    local preview_wincfg = {
      relative = "editor",
      row = preview_position.row,
      col = preview_position.col,
      width = preview_position.width,
      height = preview_position.height,
      border = __borders__.preview,
      style = "minimal",
      focusable = true,
      title = self._preview_title,
      title_pos = "center",
    }

    if preview_winnr == nil then
      preview_wincfg.noautocmd = true
      preview_winnr = vim.api.nvim_open_win(preview_bufnr, false, preview_wincfg)
      self._preview_winnr = preview_winnr

      eve.win.set_type(preview_winnr, eve.win.Types.PICKER_PREVIEW)

      local winopts = self._preview_winopts ---@type eve.ux.picker.IWinOptions
      vim.wo[preview_winnr].list = true
      vim.wo[preview_winnr].listchars = string.format(
        "eol:%s,lead:%s,nbsp:%s,space:%s,trail:%s",
        eve.icon.listchars.eol,
        eve.icon.listchars.lead,
        eve.icon.listchars.nbsp,
        eve.icon.listchars.space,
        eve.icon.listchars.trail
      )
      vim.wo[preview_winnr].number = winopts.number
      vim.wo[preview_winnr].relativenumber = false
      vim.wo[preview_winnr].spell = false
      vim.wo[preview_winnr].signcolumn = "yes"
      vim.wo[preview_winnr].winblend = winblend
      vim.wo[preview_winnr].winfixbuf = true
      vim.wo[preview_winnr].winhighlight = __highlights__.preview
      vim.wo[preview_winnr].wrap = winopts.wrap
    else
      vim.api.nvim_win_set_config(preview_winnr, preview_wincfg)

      vim.wo[preview_winnr].winfixbuf = false
      vim.api.nvim_win_set_buf(preview_winnr, preview_bufnr)
      vim.wo[preview_winnr].winfixbuf = true
    end
    vim.wo[preview_winnr].cursorline = true
  end

  return true, finder_winnr, result_winnr, preview_winnr
end

---@protected
---@param pane_focused                  eve.ux.picker.PaneEnum
---@return nil
function M:__focus_pane__(pane_focused)
  local winnr ---@type integer|nil

  if pane_focused == "finder" then
    local finder_winnr = self._finder_winnr ---@type integer|nil
    if finder_winnr ~= nil and vim.api.nvim_win_is_valid(finder_winnr) then
      winnr = finder_winnr
    end
  elseif pane_focused == "preview" then
    local preview_winnr = self._preview_winnr ---@type integer|nil
    if preview_winnr ~= nil and vim.api.nvim_win_is_valid(preview_winnr) then
      winnr = preview_winnr
    end
  elseif pane_focused == "result" then
    local result_winnr = self._result_winnr ---@type integer|nil
    if result_winnr ~= nil and vim.api.nvim_win_is_valid(result_winnr) then
      winnr = result_winnr
    end
  end

  if pane_focused ~= self._pane_focused then
    self._pane_last_focused = self._pane_focused
    self._pane_focused = pane_focused
  end

  if winnr ~= nil then
    vim.api.nvim_set_current_win(winnr)
  end
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

---@param keymaps                       eve.ux.picker.IKeymap[]
---@return eve.ux.picker.IInternalKeymap[]
function M:__resolve_keymaps__(keymaps)
  local kms = {} ---@type table<string, eve.ux.picker.IInternalKeymap>

  for _, keymap in ipairs(keymaps) do
    local disabled ---@type boolean
    if type(keymap.disabled) == "function" then
      disabled = keymap.disabled(self) ---@type boolean
    else
      disabled = not not keymap.disabled ---@type boolean
    end

    if not disabled then
      ---@type vim.keymap.set.Opts
      local opts = {
        desc = keymap.desc,
        nowait = keymap.nowait,
        noremap = keymap.noremap,
        silent = keymap.silent,
      }
      if opts.nowait == nil then
        opts.nowait = true
      end
      if opts.noremap == nil then
        opts.noremap = true
      end
      if opts.silent == nil then
        opts.silent = true
      end

      for _, mode in ipairs(keymap.modes) do
        local key = string.format("%s:%s", mode, keymap.key) ---@type string

        ---@class eve.ux.picker.IInternalKeymap
        local ikeymap = {
          mode = mode,
          key = keymap.key,
          opts = opts,
          callback = keymap.callback,
        }
        kms[key] = ikeymap

        if keymap.aliases ~= nil then
          for _, alias in ipairs(keymap.aliases) do
            local key_alias = string.format("%s:%s", mode, alias) ---@type string
            ---@class eve.ux.picker.IInternalKeymap
            local ikeymap_alias = {
              mode = mode,
              key = alias,
              opts = opts,
              callback = keymap.callback,
            }
            kms[key_alias] = ikeymap_alias
          end
        end
      end
    end
  end

  local ikeymaps = {} ---@type eve.ux.picker.IInternalKeymap[]
  for _, ikeymap in pairs(kms) do
    ikeymaps[#ikeymaps + 1] = ikeymap
  end
  return ikeymaps
end

---@return eve.ux.picker.IKeymap[]
function M:__resolve_common__keymaps__()
  local keymaps = {} ---@type eve.ux.picker.IKeymap[]

  local widget_keymaps = eve.widget.get_keymaps(self) ---@type eve.t.IKeymap[]
  for _, widget_keymap in ipairs(widget_keymaps) do
    ---@type eve.ux.picker.IKeymap
    local keymap = {
      disabled = widget_keymap.disabled,
      modes = widget_keymap.modes,
      key = widget_keymap.key,
      aliases = widget_keymap.aliases,
      desc = widget_keymap.desc,
      callback = widget_keymap.callback,
    }
    keymaps[#keymaps + 1] = keymap
  end

  for _, keymap in pairs(__keymaps__.common) do
    keymaps[#keymaps + 1] = keymap
  end

  local index = self._flags_start_index ---@type integer
  for _, item in ipairs(self._flags) do
    ---@type eve.ux.picker.IKeymap
    local keymap = {
      modes = { "n" },
      key = string.format("<leader>%d", index),
      desc = item.desc,
      callback = item.callback,
    }
    keymaps[#keymaps + 1] = keymap
    index = index + 1
  end
  return keymaps
end

---@param keymaps                       eve.ux.picker.IKeymap[]
---@return eve.ux.picker.IInternalKeymap[]
function M:__resolve_finder__keymaps__(keymaps)
  local kms = self:__resolve_common__keymaps__() ---@type eve.ux.picker.IKeymap[]
  for _, keymap in pairs(__keymaps__.finder) do
    kms[#kms + 1] = keymap
  end
  for _, keymap in ipairs(keymaps) do
    kms[#kms + 1] = keymap
  end
  return self:__resolve_keymaps__(kms)
end

---@param keymaps                       eve.ux.picker.IKeymap[]
---@return eve.ux.picker.IInternalKeymap[]
function M:__resolve_result__keymaps__(keymaps)
  local kms = self:__resolve_common__keymaps__() ---@type eve.ux.picker.IKeymap[]
  for _, keymap in pairs(__keymaps__.result) do
    kms[#kms + 1] = keymap
  end
  for _, keymap in ipairs(keymaps) do
    kms[#kms + 1] = keymap
  end
  return self:__resolve_keymaps__(kms)
end
---@param keymaps                       eve.ux.picker.IKeymap[]
---@return eve.ux.picker.IInternalKeymap[]
function M:__resolve_preview__keymaps__(keymaps)
  local kms = self:__resolve_common__keymaps__() ---@type eve.ux.picker.IKeymap[]
  for _, keymap in pairs(__keymaps__.preview) do
    kms[#kms + 1] = keymap
  end
  for _, keymap in ipairs(keymaps) do
    kms[#kms + 1] = keymap
  end
  return self:__resolve_keymaps__(kms)
end

---@return eve.ux.picker.IWinPosition
---@return eve.ux.picker.IWinPosition
---@return eve.ux.picker.IWinPosition|nil
function M:__resize__()
  local should_show_preview = self:__should_show_preview__() ---@type boolean
  local max_height = math.max(math.floor(vim.o.lines * 0.9), vim.o.lines - 10) ---@type integer
  local max_width = math.max(math.floor(vim.o.columns * 0.9), vim.o.columns - 20) ---@type integer

  local height = math.min(max_height - 3, 56) ---@type integer
  local width = math.min(max_width - 3, should_show_preview and 160 or 80) ---@type integer
  local row = math.floor((vim.o.lines - height) / 2) ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer

  local finder_width = should_show_preview and math.floor(width / 2) or width ---@type integer
  local finder_height = 1 ---@type integer

  if self._finder_multiline then
    local line_count = self._finder_line_count:snapshot() ---@type integer
    finder_height = math.max(1, math.min(5, math.floor(height * 0.3), line_count)) ---@type integer
  end

  local preview_width = width - finder_width ---@type integer

  ---@type eve.ux.picker.IWinPosition
  local finder_position = {
    row = row,
    col = col,
    height = finder_height,
    width = finder_width,
  }

  ---@type eve.ux.picker.IWinPosition
  local result_position = {
    row = row + finder_height + 1,
    col = col,
    height = height - finder_height,
    width = finder_width,
  }

  local preview_position = nil ---@type eve.ux.picker.IWinPosition|nil
  if should_show_preview then
    ---@type eve.ux.picker.IWinPosition
    preview_position = {
      row = row,
      col = col + finder_width + 1,
      height = height,
      width = preview_width,
    }
  end
  return finder_position, result_position, preview_position
end

---@param step                         integer
---@return nil
function M:__result_move_down__(step)
  local total = self._result_total:snapshot() ---@type integer
  if total > 1 then
    local lnum = self._result_lnum:snapshot() ---@type integer
    local next_lnum = eve.std.fn.navigate_circular(lnum, step, total) ---@type integer
    self._result_lnum:next(next_lnum)
  end
end

---@param next_lnum                     integer
---@return nil
function M:__result_move_to__(next_lnum)
  local total = self._result_total:snapshot() ---@type integer
  if total > 1 then
    next_lnum = math.min(total, math.max(0, next_lnum)) ---@type integer
    self._result_lnum:next(next_lnum)
  end
end

---@param finder_bufnr                  integer
---@return nil
function M:__set_finder_prompt_sign__(finder_bufnr)
  vim.fn.sign_place( --
    finder_bufnr,
    "",
    eve.var.sign.PICKER_FINDER_PROMPT,
    finder_bufnr,
    { lnum = 1, priority = 10 }
  )
end

---@return boolean
function M:__should_show_preview__()
  return vim.o.columns > 160 and self._scheduler_preview ~= nil
end

return M
