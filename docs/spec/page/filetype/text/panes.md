@/src/view/filetype/text

## Current Layout

Let use the grid to layout the panes (view / raw / transform):

1. If only one of the three panes is open, it should take the full width.
2. Else, let the whole contain takes the height as `100vh - 3rem` and full width, and make each pane `overflow: auto`.
   1. if `view` pane exist, it should take `2fr` width and full height on the left screen.
      - If only one of `raw` / `transform` pane exist, the `raw` / `transform` pane should take `1fr` width and full height on the right screen.
      - If both `raw` and `transform` panes exist, they should take `1fr` width and `1fr` height each and share the right screen.
   2. Else, let the `raw` and `transform` panes share the screen on left and right respectively.


## Task Details

I wish to add a new mode 'nav' to view the list of the transformNodes like the @src/view/filetype/jsonl/pane/nav.tsx

1. Let's add a new enum value of the `nav` inside of the ModeEnum.
2. When the `view` pane is opened and the `viewMode` is `List`, then let's show the `nav` item on the ModeToggle.
3. Let's expandTick$, activeRecordIndex$ inside of the @src/view/filetype/text/context/viewmodel.ts, they are works similar with the @src/view/filetype/jsonl/context/viewmodel.ts.
4. Let's add the chainPaths inside the transformer config, both update the server and the client side. it is used similar with the @src/view/filetype/jsonl/.
5. Let's render the `expand/collapse` button inside of the `view` pane if the `viewMode` is `List`.
6. Let's render a MultiPathInput inside of the `view` pane if the `viewMode` is `List`, it works similar to src/view/filetype/jsonl/container/MultiPathInput.tsx (duplicate the code instead of reuse it)s.
