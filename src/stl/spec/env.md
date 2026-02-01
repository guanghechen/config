# @guanghechen/stl/env - Environment Parser

A minimal .env parser with typed value support and variable interpolation.

## Design Goals

1. **Simplicity** - Parse and stringify only
2. **Zero Dependencies** - Pure JavaScript, no external packages
3. **Portable** - Works in browser and Node.js
4. **Type Coercion** - Automatic conversion for boolean, number, null
5. **Variable Interpolation** - Support `${env:VAR}` syntax

## Non-Goals

- **File I/O** - Use platform-specific APIs for file operations
- **Schema validation** - Out of scope
- **Watch mode** - Use external file watchers
- **Encryption** - Plain text only

## Types

```typescript
type IEnvPrimitive = string | number | boolean | null

type IEnvRecord = Record<string, IEnvPrimitive>

interface IStringifyEnvOptions {
  /** Keys to exclude from output */
  exclude?: string[]
}
```

## API

### Functions

| Function                   | Returns      | Description                    |
| -------------------------- | ------------ | ------------------------------ |
| `parse(content, env?)`     | `IEnvRecord` | Parse .env content into object |
| `stringify(env, options?)` | `string`     | Convert object to .env format  |

### Exports

| Export      | Type       | Description                     |
| ----------- | ---------- | ------------------------------- |
| `parse`     | `function` | Parse .env content string       |
| `stringify` | `function` | Stringify object to .env format |

## Format

### Syntax

```bash
# Comment
KEY=value
KEY = value        # Spaces around = allowed
export KEY=value   # export prefix allowed

# Quoted values
SINGLE='value'
DOUBLE="value"
BACKTICK=`value`

# Escape sequences (quoted only)
NEWLINE="line1\nline2"

# Type coercion (unquoted only)
BOOL_TRUE=true      # -> true (boolean)
BOOL_FALSE=false    # -> false (boolean)
NULL=null           # -> null
NUMBER=42           # -> 42 (number)
FLOAT=3.14          # -> 3.14 (number)

# Variable interpolation
HOME_BIN=${env:HOME}/bin
```

### Type Coercion Rules

| Input (unquoted) | Result Type | Result Value      |
| ---------------- | ----------- | ----------------- |
| `null`           | `null`      | `null`            |
| `true`           | `boolean`   | `true`            |
| `false`          | `boolean`   | `false`           |
| `42`, `3.14`     | `number`    | `42`, `3.14`      |
| `"true"`         | `string`    | `"true"` (quoted) |
| `hello`          | `string`    | `"hello"`         |

## Usage

### Basic Parsing

```javascript
import { parse } from '@guanghechen/stl/env'

const content = `
NAME=myapp
PORT=3000
DEBUG=true
SECRET=null
`

const env = parse(content)
// { NAME: 'myapp', PORT: 3000, DEBUG: true, SECRET: null }
```

### Variable Interpolation

```javascript
const content = `
BASE=/opt
DATA_DIR=\${env:BASE}/data
`

const env = parse(content)
// BASE resolved first, then used in DATA_DIR
// { BASE: '/opt', DATA_DIR: '/opt/data' }

// With pre-populated env
const env2 = parse('DATA=\${env:HOME}/data', { HOME: '/home/user' })
// { HOME: '/home/user', DATA: '/home/user/data' }
```

### Stringify

```javascript
import { stringify } from '@guanghechen/stl/env'

const env = {
  NAME: 'myapp',
  PORT: 3000,
  DEBUG: true,
  SECRET: null,
  DESC: 'Hello "World"',
}

const content = stringify(env)
// NAME=myapp
// PORT=3000
// DEBUG=true
// SECRET=null
// DESC="Hello \"World\""

// With exclusions
const filtered = stringify(env, { exclude: ['SECRET'] })
```

### Merge with Existing

```javascript
const base = { NAME: 'base', PORT: 8080 }
const content = 'NAME=override\nDEBUG=true'

const result = parse(content, base)
// result: { NAME: 'override', PORT: 8080, DEBUG: true }
// base is not mutated: { NAME: 'base', PORT: 8080 }
```
