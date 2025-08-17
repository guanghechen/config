refactor: extract main view renderer for different filetype into src/view/filetype/ from @src/view/workspace/main

## Task Details

1. Each src/view/filetype/\* structure looks like below:

   - container/       # (required) Place the piece of components (connected with the ./context/ states) for flexible and concise code structure.
   - context/         # (required) Place the shared states for all the container/ of this view such as Nav / Content and etc.
      - hook.ts       # (required) Place hooks for handling the view logic with context.
      - viewmodel.ts  # (optional) The viewmodel for the view.
      - Provider.tsx  # (optional) The context provider for the view.
      - context.ts    # (optional) The context definition for the view.
   - Composer.tsx     # (required) The component to compose other pieces to construct the basic view.
   - View.tsx         # (required) The component connect to higher context or props and pass necessary data to the Composer.

2. DO NOT try to import outer views outer of the `src/view/filetype/` such as import
   `src/view/filetype/jsonl/*` from the `src/view/filetype/text/*`. Only below codes are
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

## Requirements

1. MUST follow the new file structure for the filetype views strictly as I mentioned in the Task Details step#1.
2. DO NOT be lazy, you must take the refactor carefully as a senior engineer with flexible considerations.

