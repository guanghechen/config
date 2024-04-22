-- ----- Focus buffer -----
-- vim.keymap.set("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 1" })
-- vim.keymap.set("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 2" })
-- vim.keymap.set("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 3" })
-- vim.keymap.set("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 4" })
-- vim.keymap.set("n", "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 5" })
-- vim.keymap.set("n", "<leader>6", "<cmd>BufferLineGoToBuffer 6<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 6" })
-- vim.keymap.set("n", "<leader>7", "<cmd>BufferLineGoToBuffer 7<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 7" })
-- vim.keymap.set("n", "<leader>8", "<cmd>BufferLineGoToBuffer 8<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 8" })
-- vim.keymap.set("n", "<leader>9", "<cmd>BufferLineGoToBuffer 9<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 9" })
-- 
-- ----- Close buffer -----
-- vim.keymap.set("n", "<leader>bl", "<Cmd>BufferLineCloseLeft<cr>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the left" })
-- vim.keymap.set("n", "<leader>bh", "<Cmd>BufferLineCloseRight<cr>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the right" })
-- vim.keymap.set("n", "<leader>bo", "<Cmd>BufferLineCloseOthers<cr>", { noremap = true, silent = true, desc = "buffer: Delete other buffers" })

-- nvchad tabufline

local api = {
  gotoBuffer = function(n)
    local bufs = vim.t.bufs
    if n > 0 and n <= #bufs then
      vim.api.nvim_set_current_buf(vim.t.bufs[n])
      return
    end
  end,
  closeBuffer = function()
    require("nvchad.tabufline").close_buffer()
  end,
  closeBufferLefts = function()
    require("nvchad.tabufline").closeBufs_at_direction("left")
  end,
  closeBufferRights = function()
    require("nvchad.tabufline").closeBufs_at_direction("right")
  end,
  closeBufferOthers = function()
    require("nvchad.tabufline").closeOtherBufs()
  end,
}


local buffer = {
  gotoBuffer1 = function()
    api.gotoBuffer(1)
  end,
  gotoBuffer2 = function()
    api.gotoBuffer(2)
  end,
  gotoBuffer3 = function()
    api.gotoBuffer(3)
  end,
  gotoBuffer4 = function()
    api.gotoBuffer(4)
  end,
  gotoBuffer5 = function()
    api.gotoBuffer(5)
  end,
  gotoBuffer6 = function()
    api.gotoBuffer(6)
  end,
  gotoBuffer7 = function()
    api.gotoBuffer(7)
  end,
  gotoBuffer8 = function()
    api.gotoBuffer(8)
  end,
  gotoBuffer9 = function()
    api.gotoBuffer(9)
  end,
  closeBuffer = function()
    api.closeBuffer()
  end,
  closeBufferLefts = function()
    api.closeBufferLefts()
  end,
  closeBufferRights = function()
    api.closeBufferRights()
  end,
  closeBufferOthers = function()
    api.closeBufferOthers()
  end,
}

----- Focus buffer -----
vim.keymap.set("n", "<leader>1", buffer.gotoBuffer1, { noremap = true, silent = true, desc = "buffer: Goto buffer 1" })
vim.keymap.set("n", "<leader>2", buffer.gotoBuffer2, { noremap = true, silent = true, desc = "buffer: Goto buffer 2" })
vim.keymap.set("n", "<leader>3", buffer.gotoBuffer3, { noremap = true, silent = true, desc = "buffer: Goto buffer 3" })
vim.keymap.set("n", "<leader>4", buffer.gotoBuffer4, { noremap = true, silent = true, desc = "buffer: Goto buffer 4" })
vim.keymap.set("n", "<leader>5", buffer.gotoBuffer5, { noremap = true, silent = true, desc = "buffer: Goto buffer 5" })
vim.keymap.set("n", "<leader>6", buffer.gotoBuffer6, { noremap = true, silent = true, desc = "buffer: Goto buffer 6" })
vim.keymap.set("n", "<leader>7", buffer.gotoBuffer7, { noremap = true, silent = true, desc = "buffer: Goto buffer 7" })
vim.keymap.set("n", "<leader>8", buffer.gotoBuffer8, { noremap = true, silent = true, desc = "buffer: Goto buffer 8" })
vim.keymap.set("n", "<leader>9", buffer.gotoBuffer9, { noremap = true, silent = true, desc = "buffer: Goto buffer 9" })

----- Close buffer -----
vim.keymap.set("n", "<leader>bd", buffer.closeBuffer, { noremap = true, silent = true, desc = "buffer: Delete buffers" })
vim.keymap.set("n", "<leader>bl", buffer.closeBufferLefts, { noremap = true, silent = true, desc = "buffer: Delete buffers to the left" })
vim.keymap.set("n", "<leader>bh", buffer.closeBufferRights, { noremap = true, silent = true, desc = "buffer: Delete buffers to the right" })
vim.keymap.set("n", "<leader>bo", buffer.closeBufferOthers, { noremap = true, silent = true, desc = "buffer: Delete other buffers" })
