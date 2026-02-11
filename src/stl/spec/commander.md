# stl/commander.mjs - Modern CLI Builder

A minimal, type-safe command-line interface builder with fluent API. Supports subcommands, option
parsing, and built-in help/version handling.

## Design Goals

1. **Simplicity** - Clean, object-based configuration API
2. **Type Safety** - Full JSDoc types for IDE support
3. **Modern API** - Fluent builder pattern with method chaining
4. **Zero Dependencies** - Pure Node.js implementation
5. **Decoupled** - No implicit `process.argv`/`process.env` access, explicit input required
6. **Subcommand Support** - Nested command hierarchies with alias support
7. **Option Value Priority** - `config.default` < `argv`
8. **Option Override Semantics**
   - Array options (`string[]`, `number[]`): Multiple occurrences accumulate; type mismatch on any element triggers error
   - Scalar options: Later occurrence overrides earlier; only the final value is type-checked
9. **Bottom-up Option Shifting** - Child command options shadow parent options with the same name

## Non-Goals

The following features are intentionally NOT supported to keep simplicity:

- **Shell Completion** - Use `@guanghechen/commander` for completion support
- **Mutually exclusive options** - Handle in action handler
- **Option dependencies** - Handle in action handler
- **Sticky short option value** - `-cfoo.json` not supported; use `-c foo.json`
- **Environment variable fallback** - Use `apply` callback for custom env handling

## Types

```typescript
/** Reporter interface for logging */
interface IReporter {
  debug(message: string, ...args: unknown[]): void
  info(message: string, ...args: unknown[]): void
  warn(message: string, ...args: unknown[]): void
  error(message: string, ...args: unknown[]): void
}

/** Supported option value types */
type IOptionType = 'boolean' | 'string' | 'number' | 'string[]' | 'number[]'

/** Execution context */
interface ICommandContext {
  /** Current command node */
  cmd: ICommand
  /** Environment variables passed in */
  envs: Record<string, string | undefined>
  /** Reporter instance */
  reporter: IReporter
  /** Original argv */
  argv: string[]
}

/** Option definition */
interface IOption<T = unknown> {
  /** Long option (e.g., 'verbose' for --verbose), also used as merge key */
  long: string
  /** Short option (single character, e.g., 'v' for -v) */
  short?: string
  /** Value type, defaults to 'string' */
  type?: IOptionType
  /** Description for help text */
  description: string
  /** Whether this option is required (cannot be used with default or boolean type) */
  required?: boolean
  /** Default value when not provided */
  default?: T
  /** Allowed values for validation and completion */
  choices?: T extends Array<infer U> ? U[] : T[]
  /** Single value transformation (ignored when resolver is present) */
  coerce?: (rawValue: string) => T extends Array<infer U> ? U : T
  /** Custom resolver that fully replaces builtin parsing (ignores type/coerce) */
  resolver?: (argv: string[]) => { value: T; remaining: string[] }
  /** Callback after parsing, applies value to context */
  apply?: (value: T, ctx: ICommandContext) => void
}

/** Argument kind */
type IArgumentKind = 'required' | 'optional' | 'variadic'

/** Argument value type */
type IArgumentType = 'string' | 'number'

/** Positional argument definition */
interface IArgument<T = unknown> {
  /** Argument name */
  name: string
  /** Argument description */
  description: string
  /** Argument kind: required / optional / variadic */
  kind: IArgumentKind
  /** Value type, defaults to 'string' */
  type?: IArgumentType
  /** Default value when not provided (only effective for optional arguments) */
  default?: T
  /** Custom value transformation (takes precedence over type conversion) */
  coerce?: (rawValue: string) => T
}

/** Command configuration */
interface ICommandConfig {
  /** Command name (only effective for root command) */
  name?: string
  /** Command description */
  description: string
  /** Version (adds --version option, only effective for root command) */
  version?: string
  /** Enable built-in "help" subcommand */
  help?: boolean
  /** Optional reporter for logging (defaults to console reporter) */
  reporter?: IReporter
}

/** Command interface (readonly view) */
interface ICommand {
  readonly name: string
  readonly description: string
  readonly version: string | undefined
  readonly parent: ICommand | undefined
  readonly options: IOption[]
  readonly arguments: IArgument[]
}

/** Subcommand registration entry */
interface ISubcommandEntry {
  /** Subcommand name */
  name: string
  /** Alias names */
  aliases: string[]
  /** Subcommand instance */
  command: ICommand
}

/** Action parameters */
interface IActionParams {
  /** Execution context */
  ctx: ICommandContext
  /** Parsed options (keyed by long option name) */
  opts: Record<string, unknown>
  /** Parsed positional arguments (keyed by argument name) */
  args: Record<string, unknown>
  /** Raw positional argument strings (before type conversion) */
  rawArgs: string[]
}

/** Action handler function */
type IAction = (params: IActionParams) => void | Promise<void>

/** run() method parameters */
interface IRunParams {
  /** Command line arguments (usually process.argv.slice(2)) */
  argv: string[]
  /** Environment variables (usually process.env) */
  envs: Record<string, string | undefined>
  /** Optional reporter for logging (defaults to console reporter) */
  reporter?: IReporter
}

/** parse() method result */
interface IParseResult {
  /** Parsed options */
  opts: Record<string, unknown>
  /** Parsed positional arguments (keyed by argument name) */
  args: Record<string, unknown>
  /** Raw positional argument strings (before type conversion) */
  rawArgs: string[]
}

/** shift() method result */
interface IShiftResult {
  /** Options consumed by this command */
  opts: Record<string, unknown>
  /** Tokens not consumed, to be passed to parent */
  remaining: string[]
}

/** Error kinds for command parsing */
type ICommanderErrorKind =
  | 'UnknownOption'
  | 'MissingValue'
  | 'InvalidType'
  | 'UnsupportedShortSyntax'
  | 'OptionConflict'
  | 'MissingRequired'
  | 'InvalidChoice'
  | 'InvalidBooleanValue'
  | 'MissingRequiredArgument'
  | 'TooManyArguments'
  | 'ConfigurationError'

/** Commander error with structured information */
class CommanderError extends Error {
  readonly kind: ICommanderErrorKind
  readonly commandPath: string
  constructor(kind: ICommanderErrorKind, message: string, commandPath: string)
  /** Format error with help hint */
  format(): string
}
```

## API

### Constructor

```javascript
new Command(config: ICommandConfig)
```

### Properties

| Property          | Type                  | Description         |
| :---------------- | :-------------------- | :------------------ |
| `get name()`      | `string`              | Command name        |
| `get description` | `string`              | Command description |
| `get version()`   | `string \| undefined` | Command version     |
| `get parent()`    | `Command \| undefined`| Parent command      |
| `get options()`   | `IOption[]`           | Defined options     |
| `get arguments()` | `IArgument[]`         | Defined arguments   |

### Methods

| Method                              | Description                                |
| :---------------------------------- | :----------------------------------------- |
| `.option(opt: IOption)`             | Add option (object configuration)          |
| `.argument(arg: IArgument)`         | Add positional argument                    |
| `.action(fn: IAction)`              | Set action handler                         |
| `.subcommand(name: string, cmd)`    | Register subcommand (same cmd = alias)     |
| `.run(params: IRunParams)`          | Parse and execute                          |
| `.parse(argv: string[])`            | Parse argv, return `IParseResult`          |
| `.shift(tokens: string[])`          | Shift options, return `IShiftResult`       |
| `.formatHelp()`                     | Generate help text                         |

## Arguments

### Argument Configuration

| Property      | Type              | Description                                      |
| :------------ | :---------------- | :----------------------------------------------- |
| `name`        | `string`          | Argument name (for help text and args key)       |
| `kind`        | `IArgumentKind`   | required / optional / variadic                   |
| `description` | `string`          | Help text description                            |
| `type`        | `IArgumentType?`  | Value type (default: 'string')                   |
| `default`     | `T?`              | Default value (only for optional)                |
| `coerce`      | `(string) => T?`  | Custom value transformation                      |

### Kind Types

| Kind         | Result Type           | Example                                       |
| :----------- | :-------------------- | :-------------------------------------------- |
| `required`   | `string \| number`    | `cli foo` -> `args.file = 'foo'`              |
| `optional`   | `T \| undefined`      | `cli` -> `args.file = undefined`              |
| `variadic`   | `T[]`                 | `cli a b c` -> `args.files = ['a','b','c']`   |

### Constraints

- Required arguments must come before optional arguments
- Variadic argument can only appear once and must be last
- Required arguments cannot have a default value

### Positional Arguments with Options

Positional arguments can be mixed with options in any order:

```bash
cli foo --force           # args: ['foo'], force: true
cli --force foo           # args: ['foo'], force: true
cli foo --force bar       # args: ['foo', 'bar'], force: true
```

The `--` separator can still be used to pass arguments that look like options:

```bash
cli -- --not-an-option    # args: ['--not-an-option']
```

### Examples

```javascript
// Single required argument
.argument({ name: 'file', kind: 'required', description: 'File to process' })

// With type conversion
.argument({ name: 'port', kind: 'required', type: 'number', description: 'Port number' })

// Optional with default
.argument({ name: 'env', kind: 'optional', default: 'development', description: 'Environment' })

// Custom coerce
.argument({
  name: 'port',
  kind: 'required',
  coerce: v => {
    const n = parseInt(v, 10)
    if (n < 0 || n > 65535) throw new Error('Invalid port')
    return n
  },
  description: 'Port number'
})

// Variadic with type: number -> number[]
.argument({ name: 'numbers', kind: 'variadic', type: 'number', description: 'Numbers to sum' })
```

## Options

### Option Configuration

| Property      | Type                | Description                             |
| :------------ | :------------------ | :-------------------------------------- |
| `long`        | `string`            | Long option name (required, merge key)  |
| `short`       | `string?`           | Single character short option           |
| `type`        | `IOptionType?`      | Value type (default: 'string')          |
| `description` | `string`            | Help text description                   |
| `required`    | `boolean?`          | Whether option is required              |
| `default`     | `T?`                | Default value when not provided         |
| `choices`     | `T[]?`              | Allowed values for validation           |
| `coerce`      | `(string) => T?`    | Value transformation function           |
| `resolver`    | `(argv) => {...}?`  | Custom resolver (replaces builtin)      |
| `apply`       | `(T, ctx) => void?` | Callback after parsing                  |

### Type Examples

| Configuration                                         | Result Type | Example                               |
| :---------------------------------------------------- | :---------- | :------------------------------------ |
| `{ long: 'force', type: 'boolean' }`                  | `boolean`   | `--force` -> `true`                   |
| `{ long: 'config', type: 'string' }`                  | `string`    | `--config a --config b` -> `'b'`      |
| `{ long: 'port', type: 'number' }`                    | `number`    | `--port 3000 --port 8080` -> `8080`   |
| `{ long: 'include', type: 'string[]' }`               | `string[]`  | `--include a --include b` -> `['a','b']`|
| `{ long: 'ports', type: 'number[]' }`                 | `number[]`  | `--ports 80 --ports 443` -> `[80, 443]` |

### Examples

```javascript
// Boolean flag
.option({ long: 'force', short: 'f', type: 'boolean', description: 'Force operation' })

// String value
.option({ long: 'config', short: 'c', type: 'string', description: 'Config file path' })

// String with default
.option({ long: 'config', short: 'c', type: 'string', default: './config.json', description: 'Config file path' })

// Number value
.option({ long: 'port', short: 'p', type: 'number', default: 3000, description: 'Port number' })

// Required option
.option({ long: 'config', type: 'string', required: true, description: 'Config file path' })

// With choices validation
.option({ long: 'level', type: 'string', choices: ['debug', 'info', 'warn', 'error'], description: 'Log level' })

// With coerce transformation
.option({ long: 'date', type: 'string', coerce: v => new Date(v), description: 'Date' })

// With apply callback (for env fallback)
.option({
  long: 'port',
  type: 'number',
  default: 3000,
  description: 'Port number',
  apply: (value, ctx) => {
    // Custom handling, e.g., env fallback:
    // if (value === undefined) ctx.envs.PORT
  }
})

// String array (multiple values)
.option({ long: 'include', short: 'i', type: 'string[]', description: 'Directories to include' })

// Number array (multiple values)
.option({ long: 'ports', short: 'P', type: 'number[]', description: 'Ports to listen' })
```

### Value Syntax

Long options support both space-separated and `=` syntax:

```bash
cli --config foo.json      # space-separated
cli --config=foo.json      # equals syntax
```

### Override Semantics

```bash
# Scalar options: later wins
cli --port 3000 --port 8080         # => port: 8080
cli --config a.json --config b.json # => config: 'b.json'

# Array options: values accumulate
cli --include src --include lib     # => include: ['src', 'lib']
cli --ports 80 --ports 443          # => ports: [80, 443]
```

### Negatable Options

All boolean options automatically support negation via `--no-xxx`. Later wins:

```bash
cli --color --no-color   # => color: false
cli --no-color --color   # => color: true
```

### Short Option Combination

Multiple short boolean options can be combined. The last option may take a value:

```bash
cli -abc                    # => a: true, b: true, c: true
cli -abc foo.json           # => a: true, b: true, c: 'foo.json'
cli -a -b -c foo.json       # equivalent
```

**Note**: Sticky value syntax (`-cfoo.json`) is NOT supported.

### Option Terminator (`--`)

The double-dash `--` signals the end of options. Everything after is treated as positional arguments and won't be parsed as options:

```bash
cli --force -- --not-an-option    # => force: true, args: ['--not-an-option']
cli -- -f file.txt                # => args: ['-f', 'file.txt']
```

### Built-in Options

| Flag        | Description                       |
| :---------- | :-------------------------------- |
| `--help`    | Display help message              |
| `--version` | Display version (if configured)   |

## Subcommands

### Registration

```javascript
const root = new Command({ name: 'git', description: 'A simple git-like CLI' })

const clone = new Command({ description: 'Clone a repository' })
  .argument({ name: 'url', kind: 'required', description: 'Repository URL' })
  .option({ long: 'depth', type: 'number', description: 'Shallow clone depth' })
  .action(({ args, opts }) => {
    console.log(`Cloning ${args.url} with depth ${opts.depth ?? 'full'}`)
  })

root.subcommand('clone', clone)
```

### Subcommand Aliases

Register the same command instance multiple times to create aliases:

```javascript
const genCmd = new Command({ description: 'Generate files' })
  .action(async () => { /* ... */ })

root.subcommand('generate', genCmd)
root.subcommand('gen', genCmd)  // 'gen' becomes an alias for 'generate'
```

### Help Subcommand

Enable built-in help subcommand:

```javascript
const root = new Command({
  name: 'mycli',
  description: 'My CLI',
  help: true  // Enables: mycli help [subcommand]
})
```

Behavior:
- `mycli help` - Shows help for root command
- `mycli help <subcommand>` - Shows help for subcommand (when subcommands exist)

## Option Shifting (Bottom-up)

When a command chain is formed (root → subcommand → ...), options are processed bottom-up:

1. Leaf command processes its options first
2. Remaining tokens are passed to parent commands
3. Child options shadow parent options with the same name

```javascript
const root = new Command({ name: 'cli', description: 'Root' })
  .option({ long: 'verbose', short: 'v', type: 'boolean', description: 'Verbose' })

const sub = new Command({ description: 'Subcommand' })
  .option({ long: 'verbose', short: 'v', type: 'boolean', description: 'Sub verbose' })
  .action(({ opts }) => {
    // opts.verbose is from sub, not root (shadowing)
  })

root.subcommand('sub', sub)
```

## Error Handling

### CommanderError

When parsing fails, a `CommanderError` is thrown with structured information:

```javascript
try {
  await cli.run({ argv, envs, reporter })
} catch (err) {
  if (err instanceof CommanderError) {
    console.error(err.format())
    // Error: Unknown option '--unknown'
    // Run "mycli --help" for usage.
    process.exit(1)
  }
  throw err
}
```

### Error Kinds

| Kind                       | Example Message                               |
| :------------------------- | :-------------------------------------------- |
| `UnknownOption`            | `Unknown option '--foo'`                      |
| `MissingValue`             | `Option '--config' requires a value`          |
| `InvalidType`              | `Invalid value 'abc' for option '--port'`     |
| `UnsupportedShortSyntax`   | `Sticky short option syntax not supported`    |
| `OptionConflict`           | `Option '--verbose' is already defined`       |
| `MissingRequired`          | `Missing required option '--config'`          |
| `InvalidChoice`            | `Invalid choice 'xml' for option '--format'`  |
| `InvalidBooleanValue`      | `Invalid boolean value for '--force'`         |
| `MissingRequiredArgument`  | `Missing required argument 'file'`            |
| `TooManyArguments`         | `Too many arguments: expected 2, got 5`       |
| `ConfigurationError`       | `Variadic argument must be last`              |

## Usage Example

```javascript
import { Command } from '#stl/commander'
import { Reporter } from '#stl/reporter'

const reporter = new Reporter({ prefix: 'mycli' })

const cli = new Command({
  name: 'mycli',
  description: 'My CLI tool.',
  version: '1.0.0'
})
  .argument({ name: 'file', kind: 'optional', description: 'File to process' })
  .option({ long: 'port', short: 'p', type: 'number', default: 3000, description: 'Port number' })
  .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force operation' })
  .action(async ({ ctx, args, opts }) => {
    // ctx.cmd: Command instance
    // ctx.reporter: IReporter
    // args.file: string | undefined (the file argument)
    // opts.port: number
    // opts.force: boolean
    await handleFile(args.file)
  })

await cli.run({ argv: process.argv.slice(2), envs: process.env, reporter })
```

## Help Output

```
My CLI tool.

Usage: mycli [options] [file]

Options:
  -h, --help              Show help information
      --no-help           Negate --help
  -V, --version           Show version number
      --no-version        Negate --version
  -p, --port <value>      Port number (default: 3000)
  -f, --force             Force operation
      --no-force          Negate --force
```
