refactor: extract main view renderer for different filetype into src/view/filetype/ from
@src/view/workspace/main

1. Each src/view/filetype/\* structure looks like below:

   ```text
   container/    # (optional) Place the piece of components (connected with the ./context/ states) for flexible and concise code structure.
   context/      # (optional) Place the shared states for all the container/ of this view such as Nav / Content and etc.
   hook/         # (optional) Place hooks for handling the view logic.
   Composer.tsx  # (required) Main entry for draw the view
   index.tsx     # (required) The index file to export the main entry and usable component, hooks, types and utils.
   ```

2. DO NOT try to import outer views outer of the `src/view/filetype/` such as import
   `src/view/filetype/jsonl/*` from the `src/view/filetype/eventstream/*`. Only below codes are
   shareable:
   - src/component
   - src/constant
   - src/container
   - src/context
   - src/hook
   - src/keybindings
   - src/types
   - src/util

3. In the src/view/workspace/, let's try to reuse the codes into the src/view/filetype/\* after the
   refactor done.
