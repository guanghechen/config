-- https://gist.github.com/MunifTanjim/8d9498c096719bdf4234321230fe3dc7?permalink_comment_id=3904930#gistcomment-3904930

local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local function rename()
  local curr_name = vim.fn.expand("<cword>")

  local params = vim.lsp.util.make_position_params()

  local function on_submit(new_name)
    if not new_name or #new_name == 0 or curr_name == new_name then
      -- do nothing if `new_name` is empty or not changed.
      return
    end

    -- add `newName` property to `params`.
    -- this is needed for making `textDocument/rename` request.
    params.newName = new_name

    -- send the `textDocument/rename` request to LSP server
    vim.lsp.buf_request(0, "textDocument/rename", params, function(_, result, ctx, _)
      -- the `result` contains all the places we need to update the
      -- name of the identifier. so we apply those edits.
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if result ~= nil and client ~= nil then
        vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)

        -- after the edits are applied, the files are not saved automatically.
        -- let's remind ourselves to save those...
        local total_files = vim.tbl_count(result.changes)
        print(string.format("Changed %s file%s. To save them run ':wa'", total_files, total_files > 1 and "s" or ""))
      end
    end)
  end

  local title = "[Rename]"
  local popup_options = {
    -- place the popup window relative to the buffer position of the identifier
    relative = {
      type = "buf",
      position = {
        row = params.position.line,
        col = params.position.character,
      },
    },
    position = {
      row = 1,
      col = 0,
    },
    size = {
      width = (#curr_name < #title and #title or #curr_name) + 5,
      height = 1,
    },
    -- border for the window
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
      },
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal",
    },
  }

  local input = Input(popup_options, {
    default_value = curr_name,
    on_submit = on_submit,
    prompt = "",
  })

  input:mount()

  local actions = {
    stopinsert = function()
      vim.api.nvim_command("stopinsert")
    end,
    quit = function()
      input:unmount()
    end,
  }

  vim.schedule(actions.stopinsert)

  -- close on <esc> in normal mode
  input:map("n", "<esc>", actions.quit, { noremap = true })

  -- close when cursor leaves the buffer
  input:on(event.BufLeave, actions.quit, { once = true })
end

return rename
