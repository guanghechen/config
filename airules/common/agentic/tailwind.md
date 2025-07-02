====

REQUIREMENTS

1. **PREFER** the `I`-prefixed name for the types or interfaces, USE `IChatMessage` instead of `ChatMessage`.
2. **DON'T** run build or tests. Just run `yarn lintfix` to validate your changes.
3. **SHOULD** use tailwindcss for changing the appearance of components.
4. **SHOULD** use clsx to simplify the classnames merging. i.e.

    ```tsx
    import cn from 'clsx';

    ...

    return (
      <div className={cn('p-2', { 'm-2': hidden, 'm-0': !hidden })}>
        ...
      </div>
    )
    ```
