@/src/view/filetype/text

Let use the grid to layout the panes (view / raw / transform):

1. If only one of the three panes is open, it should take the full width.
2. Else, let the whole contain takes the height as `100vh - 3rem` and full width, and make each pane `overflow: auto`.
   1. if `view` pane exist, it should take `2fr` width and full height on the left screen.
      - If only one of `raw` / `transform` pane exist, the `raw` / `transform` pane should take `1fr` width and full height on the right screen.
      - If both `raw` and `transform` panes exist, they should take `1fr` width and `1fr` height each and share the right screen.
   2. Else, let the `raw` and `transform` panes share the screen on left and right respectively.

