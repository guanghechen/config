return {
  {
    "NvChad/ui",
    branch = "v2.5",
    lazy = false,
    config = function()
      local config = require("nvconfig").ui
      if config.tabufline.enabled then
        require("nvchad.tabufline.lazyload")
      end

      vim.api.nvim_create_autocmd("LspProgress", {
        callback = function(args)
          if string.find(args.match, "end") then
            vim.cmd("redrawstatus")
          end
          vim.cmd("redrawstatus")
        end,
      })

      vim.schedule(function()
        vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = vim.tbl_map(function(path)
            return vim.fs.normalize(vim.loop.fs_realpath(path))
          end, vim.fn.glob(vim.fn.stdpath("config") .. "/lua/**/*.lua", true, true, true)),
          group = vim.api.nvim_create_augroup("ReloadNvChad", {}),
          callback = function(opts)
            local fp = vim.fn.fnamemodify(vim.fs.normalize(vim.api.nvim_buf_get_name(opts.buf)), ":r") --[[@as string]]
            local app_name = vim.env.NVIM_APPNAME and vim.env.NVIM_APPNAME or "nvim"
            local module = string.gsub(fp, "^.*/" .. app_name .. "/lua/", ""):gsub("/", ".")

            require("plenary.reload").reload_module("nvconfig")
            require("plenary.reload").reload_module("chadrc")
            require("plenary.reload").reload_module("nvchad")
            require("plenary.reload").reload_module(module)

            require("nvchad")
          end,
        })
      end)
    end,
  },
}
