# @guanghechen/node

Personal Node.js utilities and CLI tools (ESM, zero dependencies).

## Lint

### Import Order

Imports should be sorted in the following order:

1. **Package imports** (`@**`) - Scoped packages first, sorted alphabetically
2. **Relative imports** - Sorted by path depth (deeper paths last), then alphabetically

Example:

```javascript
// 1. Package imports (@**)
import { Command } from '@guanghechen/stl/commander'
import { Reporter } from '@guanghechen/stl/reporter'

// 2. Relative imports (sorted by depth, then alphabetically)
import { PLATFORM } from '../env/platform.mjs'
import { XDG_CONFIG_HOME } from '../env/path.mjs'
import { settings } from '../env/setting.mjs'
import { apps } from './theme/_config.mjs'
import { render_template } from './theme/_util.mjs'
```
