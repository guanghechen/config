# stl/commander.mjs - Modern CLI Builder

A minimal, type-safe command-line interface builder with fluent API.

## Design Goals

1. **Simplicity** - Single command only, no subcommands
2. **Type Safety** - Full JSDoc types for IDE support
3. **Modern API** - Fluent builder pattern with method chaining
4. **Zero Dependencies** - Pure Node.js implementation
5. **Decoupled** - No implicit `process.argv`/`process.env` access, explicit input required
6. **Option Value Priority** - `config.default` < `envs[config.env]` < `argv`
7. **Option Override Semantics**
   - Array options (`string[]`, `number[]`): Multiple occurrences accumulate; type mismatch on any element triggers error
   - Scalar options: Later occurrence overrides earlier; only the final value is type-checked

## Non-Goals

The following features are intentionally NOT supported to keep simplicity:

- **Subcommands** - Use separate Command instances instead
- **Mutually exclusive options** - Handle in action handler
- **Option dependencies** - Handle in action handler
- **Custom type coercion** - Only built-in types supported; complex transforms in action handler
- **Sticky short option value** - `-cfoo.json` not supported; use `-c foo.json`

## Types

```typescript
/** Option value */
type ICommanderOptionValue = boolean | string | number | string[] | number[]

/** Argument value */
type ICommanderArgumentValue = string | string[] | undefined

/** Option type literal */
type ICommanderOptionType = 'boolean' | 'string' | 'number' | 'string[]' | 'number[]'

/** Log level */
type ICommanderLogLevel = 'debug' | 'info' | 'warn' | 'error'

/** Option configuration */
interface ICommanderOptionConfig {
  type?: ICommanderOptionType
  default?: ICommanderOptionValue
  env?: string  // Environment variable name (e.g., 'PORT')
}

/** Constructor props */
interface ICommanderProps {
  reporter?: unknown  // Reporter instance for logging
}

/** Diagnostic entry */
interface ICommanderDiagnostic {
  type: 'warn' | 'error'
  message: string
}

/** Parse result */
interface ICommanderParseResult {
  args: Record<string, ICommanderArgumentValue>
  opts: Record<string, ICommanderOptionValue>
  envs: Record<string, string>
  diagnostics: ICommanderDiagnostic[]
}

/** Execute parameters (also used by action handler) */
interface ICommanderExecuteParams {
  ctx: Command
  args: Record<string, ICommanderArgumentValue>
  opts: Record<string, ICommanderOptionValue>
  envs: Record<string, string>
}

/** Action handler */
type ICommanderActionHandler = (params: ICommanderExecuteParams) => Promise<void>
```

## API

### Constructor

```javascript
new Command(name: string, reporter: Reporter)
```

### Properties

| Property         | Type       | Description       |
| ---------------- | ---------- | ----------------- |
| `get name()`     | `string`   | Command name      |
| `get reporter()` | `Reporter` | Reporter instance |

### Methods

| Method                                                                   | Description                                        |
| ------------------------------------------------------------------------ | -------------------------------------------------- |
| `.action(handler: ICommanderActionHandler)`                              | Set action handler                                 |
| `.argument(spec: string, desc?: string)`                                 | Add positional argument                            |
| `.description(text: string)`                                             | Set command description                            |
| `.example(text: string)`                                                 | Add usage example                                  |
| `.execute(params: ICommanderExecuteParams)`                              | Execute action handler                             |
| `.option(flags: string, desc?: string, config?: ICommanderOptionConfig)` | Add option                                         |
| `.parse(argv: string[], envs: Record<string, string>)`                   | Parse and validate, return `ICommanderParseResult` |
| `.run(argv: string[], envs: Record<string, string>)`                     | Parse + execute (exit `1` on error)                |
| `.showHelp()`                                                            | Print help message                                 |
| `.strict(enabled?: boolean)`                                             | Enable/disable strict mode (default: `true`)       |
| `.version(ver: string)`                                                  | Set version (adds `--version`)                     |

## Arguments

### Spec Syntax

| Spec             | Meaning                       | Result Type           | Example                         |
| ---------------- | ----------------------------- | --------------------- | ------------------------------- |
| `<name>`         | Required argument             | `string`              | `cli foo` → `'foo'`             |
| `[name]`         | Optional argument             | `string \| undefined` | `cli` → `undefined`             |
| `[name=default]` | Optional with default         | `string`              | `cli` → `'default'`             |
| `<...names>`     | Required variadic (1+ values) | `string[]`            | `cli a b c` → `['a', 'b', 'c']` |
| `[...names]`     | Optional variadic (0+ values) | `string[]`            | `cli` → `[]`                    |

### Constraints

- Required arguments must come before optional arguments
- Variadic argument can only appear once and must be last

### Examples

```javascript
// Single required argument
.argument('<file>', 'File to process')

// Multiple arguments
.argument('<source>', 'Source file')
.argument('<dest>', 'Destination file')

// Optional argument with default
.argument('[format=json]', 'Output format')

// Variadic arguments (must be last)
.argument('<dest>', 'Destination directory')
.argument('[...files]', 'Files to copy')
```

## Options

### Flag Syntax

| Flags                     | Type Config            | Result Type | Example                                 |
| ------------------------- | ---------------------- | ----------- | --------------------------------------- |
| `-f, --force`             | (none)                 | `boolean`   | `--force` → `true`                      |
| `-c, --config <path>`     | (none)                 | `string`    | `--config a --config b` → `'b'`         |
| `-p, --port <n>`          | `{ type: 'number' }`   | `number`    | `--port 3000 --port 8080` → `8080`      |
| `-i, --include <...dirs>` | `{ type: 'string[]' }` | `string[]`  | `--include a --include b` → `['a','b']` |
| `-P, --ports <...ports>`  | `{ type: 'number[]' }` | `number[]`  | `--ports 80 --ports 443` → `[80, 443]`  |

### Examples

```javascript
// Boolean flag
.option('-f, --force', 'Force operation')

// String value (default type)
.option('-c, --config <path>', 'Config file path')

// String with default
.option('-c, --config <path>', 'Config file path', { default: './config.json' })

// Number value
.option('-p, --port <n>', 'Port number', { type: 'number', default: 3000 })

// Number with environment variable
.option('-p, --port <n>', 'Port number', { type: 'number', env: 'PORT' })

// String array (multiple values)
.option('-i, --include <...dirs>', 'Directories to include', { type: 'string[]' })

// Number array (multiple values)
.option('-P, --ports <...ports>', 'Ports to listen', { type: 'number[]' })
```

### Value Priority

Option values are resolved in the following order (later wins):

```
config.default  <  envs[config.env]  <  argv
```

Example:

```javascript
.option('-p, --port <n>', 'Port number', { type: 'number', default: 3000, env: 'PORT' })
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

Long flags are converted to camelCase:

| Flag          | Key        |
| ------------- | ---------- |
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

| Flag                  | Key        | Default | Description                           |
| --------------------- | ---------- | ------- | ------------------------------------- |
| `--help`              | `help`     | `false` | Display help message                  |
| `--version`           | `version`  | `false` | Display version (if `.version()`)     |
| `--log-level <level>` | `logLevel` | `info`  | Set log level (debug/info/warn/error) |
| `--silent`            | `silent`   | `false` | Suppress output (sets logLevel=error) |

## Validation

### Strict Mode

By default, strict mode is enabled. Unknown options trigger an error:

```bash
cli --unknown-option        # => error: Unknown option '--unknown-option'
```

Disable with `.strict(false)`:

```javascript
new Command('cli')
  .strict(false)
  .option('-f, --force', 'Force operation')
```

### Diagnostic Checks

The `.parse()` method performs validation and returns diagnostics:

| Check                     | Type    | Example Message                           |
| ------------------------- | ------- | ----------------------------------------- |
| Missing required argument | `error` | `Missing required argument '<file>'`      |
| Missing required variadic | `error` | `Missing required argument '<...files>'`  |
| Unknown option (strict)   | `error` | `Unknown option '--foo'`                  |
| Type mismatch             | `error` | `Invalid value 'abc' for option '--port'` |
| Invalid log level         | `error` | `Invalid log level 'verbose'`             |

## Usage Example

```javascript
import { Command } from '../stl/commander.mjs'

const cli = new Command('theme-apply')
  .description('Apply a theme to all configured applications.')
  .version('1.0.0')
  .argument('[theme]', 'Theme name to apply')
  .option('-p, --port <n>', 'Port number', { type: 'number', default: 3000, env: 'PORT' })
  .option('-f, --force', 'Force apply without confirmation')
  .example('theme-apply tokyonight-night')
  .example('theme-apply --silent catppuccin-mocha')
  .action(async ({ ctx, args, opts, envs }) => {
    // ctx: Command instance (ctx.name, ctx.showHelp(), etc.)
    // args.theme: string | undefined
    // opts.port: number
    // opts.force: boolean
    // envs: Record<string, string>
    await handleThemeApply(args.theme)
  })

// Option 1: All-in-one
await cli.run(process.argv.slice(2), process.env)

// Option 2: Step by step
const { args, opts, envs, diagnostics } = cli.parse(process.argv.slice(2), process.env)
if (diagnostics.length > 0) {
  for (const d of diagnostics) console.error(`[${d.type}] ${d.message}`)
  process.exit(1)
}
await cli.execute({ ctx: cli, args, opts, envs })
```

## Help Output

```
Apply a theme to all configured applications.

Usage: theme-apply [options] [theme]

Arguments:
  theme                   Theme name to apply

Options:
  --help                  Display this help message
  --version               Display version number
  --log-level <level>     Set log level (debug|info|warn|error) (default: info)
  --silent                Suppress all output except errors
  -p, --port <n>          Port number (env: PORT) (default: 3000)
  -f, --force             Force apply without confirmation

Examples:
  $ theme-apply tokyonight-night
  $ theme-apply --silent catppuccin-mocha
```
