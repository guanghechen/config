let's implement the filetype renderer for the 'text' file, it could include '.log' or '.txt' extensions files.'

## Task Details

1. feat: update @/server to support serve the '.log' and '.txt' extension files. need to set Content-Type as 'text/plain'.
2. feat: add @/src/view/filetype/text/ view, follow other filetype view like the @src/view/filetype/html:
   - A context with same file structures, but the viewmodel can only content the single `content$` by default.
   - A Composer.tsx to render the text content, simple, concise is fine.
   - A View.tsx to connect the Composer.tsx with the context.
3. feat: register the text filetype view into the @src/view/workspace and @src/view/file as other filetype views did.
