---@class ghc.command.replace.main
local M = require("ghc.command.replace.main.mod")

---Render the search/replace options
---@param state                         ghc.command.replace.state
---@param force                         boolean
---@return nil
function M.internal_render_result(state, force)
  local result = state.search(force) ---@type fml.std.oxi.search.IResult
  if result.items == nil or result.error then
    local summary = string.format("Time: %s", result.elapsed_time)
    M.internal_print(summary)
  else
    local mode = state.get_mode() ---@type ghc.enums.command.replace.Mode
    local count_files = 0
    local count_matches = 0
    local maximum_lnum = 0 ---@type integer
    ---@diagnostic disable-next-line: unused-local
    for _1, file_item in pairs(result.items) do
      count_files = count_files + 1
      ---@diagnostic disable-next-line: unused-local
      for _2, match_item in ipairs(file_item.matches) do
        count_matches = count_matches + 1
        if maximum_lnum < match_item.lnum then
          maximum_lnum = match_item.lnum
        end
      end
    end

    local summary = string.format("Files: %s, matches: %s, time: %s", count_files, count_matches, result.elapsed_time)
    M.internal_print(summary)

    M.internal_print(
      "┌─────────────────────────────────────────────────────────────────────────────",
      { { cstart = 0, cend = -1, hlname = "f_sr_result_fence" } }
    )

    local lnum_width = #tostring(maximum_lnum)
    --local continous_line_padding = "¦ " .. string.rep(" ", lnum_width) .. "  "
    local continous_line_padding = "│ " .. string.rep(" ", lnum_width) .. "  "
    local search_cwd = state.get_cwd() ---@type string
    for raw_filepath, file_item in pairs(result.items) do
      local fileicon, fileicon_highlight = fml.fn.calc_fileicon(raw_filepath)
      local filepath = fml.path.relative(search_cwd, raw_filepath)

      M.internal_print(fileicon .. " " .. filepath, {
        { cstart = 0, cend = 2, hlname = fileicon_highlight },
        { cstart = 2, cend = -1, hlname = "f_sr_filepath" },
      }, { filepath = filepath })

      if mode == "search" then
        ---@diagnostic disable-next-line: unused-local
        for _2, block_match in ipairs(file_item.matches) do
          local text = block_match.text
          for i, line in ipairs(block_match.lines) do
            ---@type fml.ui.printer.ILineHighlight[]
            local match_highlights = {
              { cstart = 0, cend = 1, hlname = "f_sr_result_fence" },
            }
            local padding = i > 1 and continous_line_padding
              or "│ " .. fml.string.pad_start(tostring(block_match.lnum), lnum_width, " ") .. ": "
            ---@diagnostic disable-next-line: unused-local
            for _3, piece in ipairs(line.p) do
              table.insert(
                match_highlights,
                { cstart = #padding + piece.l, cend = #padding + piece.r, hlname = "f_sr_opt_search_pattern" }
              )
            end
            M.internal_print(
              padding .. text:sub(line.l + 1, line.r),
              match_highlights,
              { filepath = filepath, lnum = block_match.lnum + i - 1 }
            )
          end
        end
      else
        ---@diagnostic disable-next-line: unused-local
        for _2, _block_match in ipairs(file_item.matches) do
          ---@type fml.std.oxi.replace.IPreviewBlockItem
          local block_match = fml.oxi.replace_text_preview({
            text = _block_match.text,
            search_pattern = state.get_search_pattern(),
            replace_pattern = state.get_replace_pattern(),
            keep_search_pieces = true,
            flag_regex = state.get_flag_regex(),
            flag_case_sensitive = state.get_flag_case_sensitive(),
          })

          local text = block_match.text ---@type string
          local start_lnum = _block_match.lnum ---@type integer
          for i, line in ipairs(block_match.lines) do
            ---@type fml.ui.printer.ILineHighlight[]
            local match_highlights = {
              { cstart = 0, cend = 1, hlname = "f_sr_result_fence" },
            }
            local padding = i > 1 and continous_line_padding
              or "│ " .. fml.string.pad_start(tostring(start_lnum), lnum_width, " ") .. ": "
            ---@diagnostic disable-next-line: unused-local
            for _3, piece in ipairs(line.p) do
              local hlname = piece.i % 2 == 0 and "f_sr_text_deleted" or "f_sr_text_added" ---@type string
              table.insert(
                match_highlights,
                { cstart = #padding + piece.l, cend = #padding + piece.r, hlname = hlname }
              )
            end
            M.internal_print(
              padding .. text:sub(line.l + 1, line.r),
              match_highlights,
              { filepath = filepath, lnum = start_lnum + i - 1 }
            )
          end
        end
      end
    end

    M.internal_print(
      "└─────────────────────────────────────────────────────────────────────────────",
      { { cstart = 0, cend = -1, hlname = "f_sr_result_fence" } }
    )
  end
end
