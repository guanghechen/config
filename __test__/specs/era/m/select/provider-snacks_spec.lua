local picker = require("__test__.support.picker")
local t = require("__test__.support.harness").new()

t:test("Snacks items with equal names retain distinct native rows and action payloads", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    choices={{name="same",text="same",value=1},{name="same",text="same",value=2}}
    local data=require("era.m.select.provider-snacks")(choices,{format_item=function(item) return item.text end})
    picker:reset_data(data)
  ]])
  ui:wait_lua("return picker._treeview:linecount()==2 or #errors>0", 5000, "choices published")
  t.assert_eq(0, ui:lua("return #errors"))
  t.assert_true(ui:lua("return picker:retrieve(1).data.original_item==choices[1]"))
  t.assert_true(ui:lua("return picker:retrieve(2).data.original_item==choices[2]"))
end)

t:test("snacks escapes control characters while preserving original choices", function()
  local ui = picker.list_ui(t)
  ui:lua([[
    choices={"carriage\rreturn", "zero\0byte"}
    local data=require("era.m.select.provider-snacks")(choices,{format_item=function(item) return item end})
    picker:reset_data(data)
  ]])
  ui:wait_lua("return picker._treeview:linecount()==2 or #errors>0", 5000, "choices published")
  t.assert_eq(0, ui:lua("return #errors"))
  t.assert_true(ui:lua("return picker:retrieve(1).data.original_item==choices[1]"))
  t.assert_true(ui:lua("return picker:retrieve(2).data.original_item==choices[2]"))
  t.assert_true(ui:lua([[
    local text=table.concat(vim.api.nvim_buf_get_lines(picker.result:get_bufnr(),0,-1,false))
    return text:find("carriage\\rreturn",1,true)~=nil and text:find("zero\\0byte",1,true)~=nil
  ]]))
end)

t:run()
