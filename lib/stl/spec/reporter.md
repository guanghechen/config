# @guanghechen/stl/reporter - Colored Console Logger

A minimal, level-based logging utility with colored output and breadcrumb prefix support.

## Design Goals

1. **Simplicity** - Four log levels only (debug, info, warn, error)
2. **Zero Dependencies** - Pure JavaScript, no external packages
3. **Decoupled** - No implicit `process.argv` access, explicit props required
4. **Breadcrumb Prefix** - Hierarchical context via `.attach()` / `.detach()`
5. **Lazy Evaluation** - Function arguments for deferred computation
6. **Testable** - Built-in mock mode for capturing logs
7. **Portable** - Injectable output for browser/custom environments

## Non-Goals

- **File logging** - Use shell redirection or custom output
- **Log rotation** - Out of scope
- **Custom formatters** - Fixed format only

## Types

```typescript
type IReporterLevel = 'debug' | 'info' | 'warn' | 'error'

type IReporterOutput = (level: IReporterLevel, parts: string[], args: unknown[]) => void

interface IReporterFlight {
  date?: boolean   // Include ISO timestamp (default: true)
  color?: boolean  // Use ANSI colors (default: true)
}

interface IReporterProps {
  prefix?: string           // Initial prefix, cannot contain ':' (e.g., 'app')
  level?: IReporterLevel    // Minimum log level (default: 'info')
  flight?: IReporterFlight  // Output control
  output?: IReporterOutput  // Custom output function (default: console)
}

interface IReporterEntry {
  level: IReporterLevel
  prefixes: string[]
  args: unknown[]
  date: Date
}
```

## API

### Constructor

```javascript
new Reporter(props?: IReporterProps)
```

| Option         | Type              | Default         | Description                      |
| -------------- | ----------------- | --------------- | -------------------------------- |
| `prefix`       | `string`          | `undefined`     | Initial prefix, cannot contain `:` |
| `level`        | `IReporterLevel`  | `'info'`        | Minimum log level to output      |
| `flight.date`  | `boolean`         | `true`          | Include ISO timestamp            |
| `flight.color` | `boolean`         | `true`          | Use ANSI color codes             |
| `output`       | `IReporterOutput` | (console)       | Custom output function           |

### Methods

| Method                 | Returns            | Description                                                     |
| ---------------------- | ------------------ | --------------------------------------------------------------- |
| `.attach(prefix)`      | `this`             | Push prefix to breadcrumb stack (cannot contain `:`)            |
| `.detach()`            | `this`             | Pop prefix from stack (initial prefix is protected)             |
| `.mock()`              | `this`             | Enable mock mode (capture instead of print)                     |
| `.collect()`           | `IReporterEntry[]` | Disable mock mode, return captured logs                         |
| `.log(level, ...args)` | `void`             | Core logging method (invalid level falls back to default)       |
| `.debug(...args)`      | `this`             | Log at debug level (`console.debug`)                            |
| `.info(...args)`       | `this`             | Log at info level (`console.log`)                               |
| `.warn(...args)`       | `this`             | Log at warn level (`console.warn`)                              |
| `.error(...args)`      | `this`             | Log at error level (`console.error`)                            |

### Exports

| Export     | Type    | Description       |
| ---------- | ------- | ----------------- |
| `Reporter` | `class` | Main logger class |

## Log Levels

| Level   | Numeric | Color  | ANSI Code  |
| ------- | ------- | ------ | ---------- |
| `debug` | 0       | Gray   | `\x1b[90m` |
| `info`  | 1       | Cyan   | `\x1b[36m` |
| `warn`  | 2       | Yellow | `\x1b[33m` |
| `error` | 3       | Red    | `\x1b[31m` |

Messages are output only if level >= threshold.

## Output Format

```
[timestamp?] [prefixes|level] message...
```

| Segment   | Color       | Description                       |
| --------- | ----------- | --------------------------------- |
| timestamp | Gray (dim)  | ISO 8601 format                   |
| `[` `]`   | Gray (dim)  | Brackets                          |
| prefix    | Level color | Each prefix segment               |
| `:`       | Gray (dim)  | Separator between prefixes        |
| message   | Default     | Log content (no color applied)    |

Example with `flight.color: true`:

```
2024-01-15T10:30:00.000Z [app:theme] Starting
└──────── dim ─────────┘ ││   ││  │ └─ default
                         ││   │└──┴─ dim
                         │└───┴─ cyan (info level)
                         └─ dim
```

## Usage

### Basic

```javascript
import { Reporter } from '@guanghechen/stl/reporter'

const reporter = new Reporter({ prefix: 'app' })

reporter.debug('verbose info')
reporter.info('starting')
reporter.warn('missing config')
reporter.error('failed:', err)
```

### Breadcrumb Prefix

```javascript
const reporter = new Reporter({ prefix: 'app' })

reporter.info('Starting')             // [app] Starting

reporter.attach('theme')
reporter.info('Loading')              // [app:theme] Loading

reporter.attach('apply')
reporter.info('Applying')             // [app:theme:apply] Applying

reporter.detach()
reporter.info('Done')                 // [app:theme] Done
```

Without prefix, falls back to level name: `[info]`, `[warn]`, `[error]`.

### Context Pattern

Pass reporter through context, use `.attach()` / `.detach()` for scope:

```javascript
const ctx = { reporter: new Reporter({ prefix: 'app' }) }

async function initTheme(ctx) {
  ctx.reporter.attach('theme')
  try {
    ctx.reporter.info('Loading config')
  } finally {
    ctx.reporter.detach()
  }
}
```

### Lazy Evaluation

Function arguments are only called if the log level passes:

```javascript
const reporter = new Reporter({ level: 'info' })

// Never called (debug < info)
reporter.debug(() => expensiveComputation())

// Called only when needed
reporter.info('User:', () => fetchUser(id))
```

### Flight Options

```javascript
// No timestamp
new Reporter({ prefix: 'cli', flight: { date: false } })

// No colors (for file output)
new Reporter({ prefix: 'app', flight: { color: false } })
```

### Custom Output

Inject custom output for browser or testing:

```javascript
// Browser with styled console
const browserOutput = (level, parts, args) => {
  const styles = { debug: 'color:gray', info: 'color:blue', warn: 'color:orange', error: 'color:red' }
  console.log(`%c[${level}]`, styles[level], ...args)
}

const reporter = new Reporter({
  prefix: 'app',
  flight: { color: false },
  output: browserOutput,
})
```

### Mock Mode

Capture logs for testing:

```javascript
const reporter = new Reporter({ prefix: 'test', level: 'debug' })

reporter.mock()

reporter.info('Starting')
reporter.attach('sub')
reporter.warn('Warning!')
reporter.detach()

const logs = reporter.collect()

assert.equal(logs.length, 2)
assert.deepEqual(logs[0], {
  level: 'info',
  prefixes: ['test'],
  args: ['Starting'],
  date: /* Date instance */
})
assert.deepEqual(logs[1].prefixes, ['test', 'sub'])
```
