return {
  "SmiteshP/nvim-navic",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  init = function()
    vim.api.nvim_create_autocmd("LspAttach", {
      desc = "Navic Attacher",
      group = fml.fn.augroup("navic_attach"),
      callback = function(a)
        local client_id = fml.object.get(a, "data.client_id")
        fml.debug.log({ a = a, client_id = client_id })
        if client_id ~= nil then
          local client = vim.lsp.get_client_by_id(client_id)
          if client and client.server_capabilities["documentSymbolProvider"] then
            local navic = require("nvim-navic")
            navic.attach(client, a.buf)
          end
        end
      end,
    })
  end,
  opts = {
    icons = {
      Array = fml.ui.icons.kind.Array,
      Boolean = fml.ui.icons.kind.Boolean,
      Class = fml.ui.icons.kind.Class,
      Constant = fml.ui.icons.kind.Constant,
      Constructor = fml.ui.icons.kind.Constructor,
      Enum = fml.ui.icons.kind.Enum,
      EnumMember = fml.ui.icons.kind.EnumMember,
      Event = fml.ui.icons.kind.Event,
      Field = fml.ui.icons.kind.Field,
      File = fml.ui.icons.kind.File,
      Function = fml.ui.icons.kind.Function,
      Interface = fml.ui.icons.kind.Interface,
      Key = fml.ui.icons.kind.Key,
      Method = fml.ui.icons.kind.Method,
      Module = fml.ui.icons.kind.Module,
      Namespace = fml.ui.icons.kind.Namespace,
      Null = fml.ui.icons.kind.Null,
      Number = fml.ui.icons.kind.Number,
      Object = fml.ui.icons.kind.Object,
      Operator = fml.ui.icons.kind.Operator,
      Package = fml.ui.icons.kind.Package,
      Property = fml.ui.icons.kind.Property,
      String = fml.ui.icons.kind.String,
      Struct = fml.ui.icons.kind.Struct,
      TypeParameter = fml.ui.icons.kind.TypeParameter,
      Variable = fml.ui.icons.kind.Variable,
    },
  },
}
