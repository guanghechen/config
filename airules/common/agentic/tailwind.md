## REQUIREMENTS

1. **DON'T** run build or tests. Just run `yarn lintfix` to validate your changes.
2. **SHOULD** use tailwindcss for changing the appearance of components.
3. **SHOULD** use clsx to simplify the classnames merging. i.e.

    ```tsx
    import cn from 'clsx';

    ...

    return (
      <div className={cn('p-2', { 'm-2': hidden, 'm-0': !hidden })}>
        ...
      </div>
    )
    ```

