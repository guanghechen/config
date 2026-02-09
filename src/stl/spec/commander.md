# stl/commander.mjs - Modern CLI Builder

A minimal, type-safe command-line interface builder with fluent API. Supports subcommands, option
parsing, and built-in help/version handling.

## Design Goals

1. **Simplicity** - Clean, object-based configuration API
2. **Type Safety** - Full JSDoc types for IDE support
3. **Modern API** - Fluent builder pattern with method chaining
4. **Zero Dependencies** - Pure Node.js implementation
5. **Decoupled** - No implicit `process.argv`/`process.env` access, explicit input required
6. **Subcommand Support** - Nested command hierarchies
7. **Option Value Priority** - `config.default` < `argv`
8. **Option Override Semantics**
   - Array options (`string[]`, `number[]`): Multiple occurrences accumulate; type mismatch on any element triggers error
   - Scalar options: Later occurrence overrides earlier; only the final value is type-checked

## Non-Goals

The following features are intentionally NOT supported to keep simplicity:

- **Shell Completion** - Use `@guanghechen/commander` for completion support
- **Mutually exclusive options** - Handle in action handler
- **Option dependencies** - Handle in action handler
- **Custom type coercion** - Only built-in types supported; complex transforms in action handler
- **Sticky short option value** - `-cfoo.json` not supported; use `-c foo.json`

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

/** Option definition */
interface IOption<T = unknown> {
  /** Long option (e.g., 'verbose' for --verbose), also used as merge key */
  long: string
  /** Short option (single character, e.g., 'v' for -v) */
  short?: string
  /** Value type, defaults to 'string' */
  type?: IOptionType
  /** Description for help text */
  description?: string
  /** Default value when not provided */
  default?: T
  /** Environment variable name to read value from */
  env?: string
}

/** Argument kind */
type IArgumentKind = 'required' | 'optional' | 'variadic'

/** Positional argument definition */
interface IArgument {
  /** Argument name */
  name: string
  /** Argument description */
  description?: string
  /** Argument kind: required / optional / variadic */
  kind: IArgumentKind
  /** Default value for optional arguments */
  default?: string
}

/** Command configuration */
interface ICommandConfig {
  /** Command name */
  name: string
  /** Command description */
  description?: string
  /** Version (adds --version option) */
  version?: string
  /** Enable built-in "help" subcommand (default: false) */
  helpSubcommand?: boolean
}

/** Command interface (readonly view) */
interface ICommand {
  readonly name: string
  readonly description: string | undefined
  readonly version: string | undefined
  readonly options: IOption[]
  readonly arguments: IArgument[]
}

/** Execution context */
interface ICommandContext {
  /** Current command instance */
  cmd: ICommand
  /** Environment variables passed in */
  envs: Record<string, string | undefined>
  /** Reporter instance */
  reporter: IReporter
  /** Original argv */
  argv: string[]
}

/** Action parameters */
interface IActionParams {
  /** Execution context */
  ctx: ICommandContext
  /** Parsed options (keyed by long option name) */
  opts: Record<string, unknown>
  /** Parsed positional arguments */
  args: Record<string, string | string[] | undefined>
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
  /** Parsed positional arguments */
  args: Record<string, string | string[] | undefined>
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
| `get description` | `string \| undefined` | Command description |
| `get version()`   | `string \| undefined` | Command version     |
| `get options()`   | `IOption[]`           | Defined options     |
| `get arguments()` | `IArgument[]`         | Defined arguments   |

### Methods

| Method                              | Description                         |
| :---------------------------------- | :---------------------------------- |
| `.option(opt: IOption)`             | Add option (object configuration)   |
| `.argument(arg: IArgument)`         | Add positional argument             |
| `.action(fn: IAction)`              | Set action handler                  |
| `.subcommand(name: string, cmd)`    | Register subcommand                 |
| `.run(params: IRunParams)`          | Parse and execute                   |
| `.parse(argv: string[])`            | Parse argv, return `IParseResult`   |
| `.formatHelp()`                     | Generate help text                  |

## Arguments

### Argument Configuration

| Property      | Type            | Description                   |
| :------------ | :-------------- | :---------------------------- |
| `name`        | `string`        | Argument name (used as key)   |
| `kind`        | `IArgumentKind` | required / optional / variadic |
| `description` | `string?`       | Help text description         |
| `default`     | `string?`       | Default value (optional only) |

### Kind Types

| Kind         | Result Type           | Example                         |
| :----------- | :-------------------- | :------------------------------ |
| `required`   | `string`              | `cli foo` -> `'foo'`            |
| `optional`   | `string \| undefined` | `cli` -> `undefined`            |
| `variadic`   | `string[]`            | `cli a b c` -> `['a', 'b', 'c']`|

### Constraints

- Required arguments must come before optional arguments
- Variadic argument can only appear once and must be last

### Examples

```javascript
// Single required argument
.argument({ name: 'file', kind: 'required', description: 'File to process' })

// Multiple arguments
.argument({ name: 'source', kind: 'required', description: 'Source file' })
.argument({ name: 'dest', kind: 'required', description: 'Destination file' })

// Optional argument with default
.argument({ name: 'format', kind: 'optional', description: 'Output format', default: 'json' })

// Variadic arguments (must be last)
.argument({ name: 'dest', kind: 'required', description: 'Destination directory' })
.argument({ name: 'files', kind: 'variadic', description: 'Files to copy' })
```

## Options

### Option Configuration

| Property      | Type           | Description                             |
| :------------ | :------------- | :-------------------------------------- |
| `long`        | `string`       | Long option name (required, merge key)  |
| `short`       | `string?`      | Single character short option           |
| `type`        | `IOptionType?` | Value type (default: 'boolean')         |
| `description` | `string?`      | Help text description                   |
| `default`     | `T?`           | Default value when not provided         |
| `env`         | `string?`      | Environment variable name               |

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

// Number with environment variable
.option({ long: 'port', short: 'p', type: 'number', env: 'PORT', description: 'Port number' })

// String array (multiple values)
.option({ long: 'include', short: 'i', type: 'string[]', description: 'Directories to include' })

// Number array (multiple values)
.option({ long: 'ports', short: 'P', type: 'number[]', description: 'Ports to listen' })
```

### Value Priority

Option values are resolved in the following order (later wins):

```
config.default  <  envs[config.env]  <  argv
```

Example:

```javascript
.option({ long: 'port', short: 'p', type: 'number', default: 3000, env: 'PORT', description: 'Port number' })
```

```bash
# config.default only
cli                        # => port: 3000

# envs[config.env] overrides default
PORT=8080 cli              # => port: 8080

# argv overrides all
PORT=8080 cli --port 9000  # => port: 9000
```

### Value Syntax

Long options support both space-separated and `=` syntax:

```bash
cli --config foo.json      # space-separated
cli --config=foo.json      # equals syntax
```

### Key Conversion

Long flags are converted to camelCase for the `opts` object:

| Flag          | Key        |
| :------------ | :--------- |
| `--silent`    | `silent`   |
| `--log-level` | `logLevel` |
| `--no-color`  | `color`    |

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

The double-dash `--` signals the end of options. Everything after is treated as positional arguments:

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

const clone = new Command({ name: 'clone', description: 'Clone a repository' })
  .argument({ name: 'url', kind: 'required', description: 'Repository URL' })
  .option({ long: 'depth', type: 'number', description: 'Shallow clone depth' })
  .action(({ args, opts }) => {
    console.log(`Cloning ${args.url} with depth ${opts.depth ?? 'full'}`)
  })

root.subcommand('clone', clone)
```

### Help Subcommand

Enable built-in help subcommand for subcommand help:

```javascript
const root = new Command({
  name: 'mycli',
  description: 'My CLI',
  helpSubcommand: true  // Enables: mycli help <subcommand>
})
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
| `OptionConflict`           | `Option '--verbose' conflicts with existing`  |
| `MissingRequired`          | `Missing required option '--config'`          |
| `InvalidChoice`            | `Invalid choice 'xml' for option '--format'`  |
| `InvalidBooleanValue`      | `Invalid boolean value for '--force'`         |
| `MissingRequiredArgument`  | `Missing required argument 'file'`            |
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
  .option({ long: 'port', short: 'p', type: 'number', default: 3000, env: 'PORT', description: 'Port number' })
  .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force operation' })
  .action(async ({ ctx, args, opts }) => {
    // ctx.cmd: Command instance
    // ctx.reporter: IReporter
    // args.file: string | undefined
    // opts.port: number
    // opts.force: boolean
    await handleFile(args.file)
  })

// Option 1: All-in-one
await cli.run({ argv: process.argv.slice(2), envs: process.env, reporter })

// Option 2: Step by step
const { args, opts } = cli.parse(process.argv.slice(2))
await cli.execute({ ctx: cli, args, opts })
```

## Help Output

```
My CLI tool.

Usage: mycli [options] [file]

Arguments:
  file                    File to process

Options:
  --help                  Display this help message
  --version               Display version number
  -p, --port <n>          Port number (env: PORT) (default: 3000)
  -f, --force             Force operation
```
