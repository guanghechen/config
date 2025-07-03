====

WORKFLOW

1. **MUST**: use `yarn` instead of `npm` to manage packages and run scripts.
2. **MUST**: only run `yarn lintfix` to validate changes


====

REQUIREMENTS

1. **MUST**: Use `I`-prefixed naming convention for types and interfaces.names for interfaces/types (`IChatMessage`, `IUser`)
2. **MUST**: Use `React.useXX` instead of direct hook imports (`React.useState`, `React.useEffect`)
3. **MUST**: Use Tailwind CSS classes only, no inline styles
4. **MUST**: Use `clsx` imported as `cn` for conditional classes:

    ```tsx
    import cn from 'clsx';
    className={cn('base-class', { 'conditional': condition })}
    ```

5. **SHOULD**: Keep components small, use clear names, maintain formatting

