return {
  "smear-cursor.nvim",
  event = { "VeryLazy" },
  opts = {
    smear_between_buffers = true,
    smear_between_neighbor_lines = true,
    scroll_buffer_space = true,

    cursor_color = nil,
    distance_stop_animating = 0.5,
    hide_target_hack = true,
    stiffness = 0.8,
    trailing_stiffness = 0.5,
  },
}
