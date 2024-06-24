local scheme = fml.api.highlight.Scheme.new()

---integrage replace
scheme
  :register("kyokuya_invisible", { fg = "none", bg = "none" })
  :register("kyokuya_replace_cfg_name", { fg = "blue", bg = "none", bold = true })
  :register("kyokuya_replace_cfg_replace_pattern", { fg = "diff_add_hl", bg = "none" })
  :register("kyokuya_replace_cfg_search_pattern", { fg = "diff_delete_hl", bg = "none" })
  :register("kyokuya_replace_cfg_value", { fg = "yellow", bg = "none" })
  :register("kyokuya_replace_filepath", { fg = "blue", bg = "none" })
  :register("kyokuya_replace_flag", { fg = "white", bg = "grey" })
  :register("kyokuya_replace_flag_enabled", { fg = "black", bg = "baby_pink" })
  :register("kyokuya_replace_result_fence", { fg = "grey", bg = "none" })
  :register("kyokuya_replace_text_deleted", { fg = "diff_delete_hl", strikethrough = true })
  :register("kyokuya_replace_text_added", { fg = "diff_add_hl", bg = "none" })
  :register("kyokuya_replace_usage", { fg = "grey_fg2", bg = "none" })

return scheme
