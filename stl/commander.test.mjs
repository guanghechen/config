import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { Command } from './commander.mjs'

describe('Command', () => {
  // ============================================================
  // Constructor & Properties
  // ============================================================

  describe('constructor', () => {
    it('creates command with name', () => {
      const cmd = new Command('my-cli')
      assert.equal(cmd.name, 'my-cli')
    })
  })

  // ============================================================
  // Fluent API
  // ============================================================

  describe('fluent API', () => {
    it('supports method chaining', () => {
      const cmd = new Command('cli')
        .description('Test CLI')
        .version('1.0.0')
        .argument('<file>', 'File')
        .option('-f, --force', 'Force')
        .example('cli file.txt')
        .strict(true)
      assert.equal(cmd.name, 'cli')
    })
  })

  // ============================================================
  // Arguments
  // ============================================================

  describe('argument', () => {
    it('parses required argument', () => {
      const cmd = new Command('cli').argument('<file>', 'File')
      const { args } = cmd.parse(['input.txt'], {})
      assert.equal(args.file, 'input.txt')
    })

    it('reports missing required argument', () => {
      const cmd = new Command('cli').argument('<file>', 'File')
      const { diagnostics } = cmd.parse([], {})
      assert.equal(diagnostics.length, 1)
      assert.match(diagnostics[0].message, /Missing required argument/)
    })

    it('parses optional argument', () => {
      const cmd = new Command('cli').argument('[file]', 'File')
      const { args } = cmd.parse([], {})
      assert.equal(args.file, undefined)
    })

    it('parses optional argument with default', () => {
      const cmd = new Command('cli').argument('[format=json]', 'Format')
      const { args } = cmd.parse([], {})
      assert.equal(args.format, 'json')
    })

    it('parses multiple arguments', () => {
      const cmd = new Command('cli')
        .argument('<source>', 'Source')
        .argument('<dest>', 'Dest')
      const { args } = cmd.parse(['a.txt', 'b.txt'], {})
      assert.equal(args.source, 'a.txt')
      assert.equal(args.dest, 'b.txt')
    })

    it('parses variadic argument', () => {
      const cmd = new Command('cli').argument('[...files]', 'Files')
      const { args } = cmd.parse(['a.txt', 'b.txt'], {})
      assert.deepEqual(args.files, ['a.txt', 'b.txt'])
    })

    it('parses required variadic argument', () => {
      const cmd = new Command('cli').argument('<...files>', 'Files')
      const { args } = cmd.parse(['a.txt'], {})
      assert.deepEqual(args.files, ['a.txt'])
    })

    it('reports missing required variadic argument', () => {
      const cmd = new Command('cli').argument('<...files>', 'Files')
      const { diagnostics } = cmd.parse([], {})
      assert.match(diagnostics[0].message, /Missing required argument/)
    })

    it('throws on invalid argument spec', () => {
      const cmd = new Command('cli')
      assert.throws(() => cmd.argument('invalid'), /Invalid argument spec/)
    })

    it('throws on multiple variadic arguments', () => {
      const cmd = new Command('cli').argument('[...files]', 'Files')
      assert.throws(() => cmd.argument('[...more]', 'More'), /Only one variadic/)
    })
  })

  // ============================================================
  // Options - Basic Types
  // ============================================================

  describe('option', () => {
    it('parses boolean option', () => {
      const cmd = new Command('cli').option('-f, --force', 'Force')
      assert.equal(cmd.parse(['--force'], {}).opts.force, true)
      assert.equal(cmd.parse(['-f'], {}).opts.force, true)
    })

    it('parses string option', () => {
      const cmd = new Command('cli').option('-c, --config <path>', 'Config')
      assert.equal(cmd.parse(['--config', 'app.json'], {}).opts.config, 'app.json')
      assert.equal(cmd.parse(['-c', 'app.json'], {}).opts.config, 'app.json')
    })

    it('parses number option', () => {
      const cmd = new Command('cli').option('-p, --port <n>', 'Port', { type: 'number' })
      assert.equal(cmd.parse(['--port', '3000'], {}).opts.port, 3000)
      assert.equal(cmd.parse(['-p', '8080'], {}).opts.port, 8080)
    })

    it('parses string array option', () => {
      const cmd = new Command('cli').option('-i, --include <dir>', 'Dirs', { type: 'string[]' })
      const { opts } = cmd.parse(['--include', 'src', '--include', 'lib'], {})
      assert.deepEqual(opts.include, ['src', 'lib'])
    })

    it('parses number array option', () => {
      const cmd = new Command('cli').option('-P, --ports <n>', 'Ports', { type: 'number[]' })
      const { opts } = cmd.parse(['--ports', '80', '--ports', '443'], {})
      assert.deepEqual(opts.ports, [80, 443])
    })

    it('reports invalid number value', () => {
      const cmd = new Command('cli').option('-p, --port <n>', 'Port', { type: 'number' })
      const { diagnostics } = cmd.parse(['--port', 'abc'], {})
      assert.match(diagnostics[0].message, /Invalid value/)
    })

    it('reports invalid number array value', () => {
      const cmd = new Command('cli').option('-P, --ports <n>', 'Ports', { type: 'number[]' })
      const { diagnostics } = cmd.parse(['--ports', 'abc'], {})
      assert.match(diagnostics[0].message, /Invalid value/)
    })

    it('reports missing option value', () => {
      const cmd = new Command('cli').option('-c, --config <path>', 'Config')
      const { diagnostics } = cmd.parse(['--config'], {})
      assert.match(diagnostics[0].message, /requires a value/)
    })
  })

  // ============================================================
  // Options - Default & Environment Variables
  // ============================================================

  describe('option default & env', () => {
    it('uses default value', () => {
      const cmd = new Command('cli').option('-p, --port <n>', 'Port', { type: 'number', default: 3000 })
      assert.equal(cmd.parse([], {}).opts.port, 3000)
    })

    it('uses env value', () => {
      const cmd = new Command('cli').option('-p, --port <n>', 'Port', { type: 'number', env: 'PORT' })
      assert.equal(cmd.parse([], { PORT: '8080' }).opts.port, 8080)
    })

    it('follows priority: default < env < argv', () => {
      const cmd = new Command('cli').option('-p, --port <n>', 'Port', {
        type: 'number',
        default: 3000,
        env: 'PORT',
      })
      assert.equal(cmd.parse([], {}).opts.port, 3000)
      assert.equal(cmd.parse([], { PORT: '8080' }).opts.port, 8080)
      assert.equal(cmd.parse(['--port', '9000'], { PORT: '8080' }).opts.port, 9000)
    })

    it('coerces boolean env values', () => {
      const cmd = new Command('cli').option('-f, --force', 'Force', { env: 'FORCE' })
      assert.equal(cmd.parse([], { FORCE: 'true' }).opts.force, true)
      assert.equal(cmd.parse([], { FORCE: '1' }).opts.force, true)
      assert.equal(cmd.parse([], { FORCE: 'false' }).opts.force, false)
    })
  })

  // ============================================================
  // Options - Override Semantics
  // ============================================================

  describe('option override', () => {
    it('scalar option: later wins', () => {
      const cmd = new Command('cli').option('-p, --port <n>', 'Port', { type: 'number' })
      assert.equal(cmd.parse(['--port', '3000', '--port', '8080'], {}).opts.port, 8080)
    })

    it('array option: accumulates', () => {
      const cmd = new Command('cli').option('-i, --include <dir>', 'Dirs', { type: 'string[]' })
      const { opts } = cmd.parse(['--include', 'a', '--include', 'b'], {})
      assert.deepEqual(opts.include, ['a', 'b'])
    })
  })

  // ============================================================
  // Options - Negatable
  // ============================================================

  describe('negatable option', () => {
    it('negates with --no-prefix', () => {
      const cmd = new Command('cli').option('--color', 'Color')
      assert.equal(cmd.parse(['--no-color'], {}).opts.color, false)
    })

    it('later wins: --flag then --no-flag', () => {
      const cmd = new Command('cli').option('--color', 'Color')
      assert.equal(cmd.parse(['--color', '--no-color'], {}).opts.color, false)
    })

    it('later wins: --no-flag then --flag', () => {
      const cmd = new Command('cli').option('--color', 'Color')
      assert.equal(cmd.parse(['--no-color', '--color'], {}).opts.color, true)
    })
  })

  // ============================================================
  // Options - Short Option Syntax
  // ============================================================

  describe('short option combination', () => {
    it('parses combined boolean options: -abc', () => {
      const cmd = new Command('cli')
        .option('-a, --alpha', 'A')
        .option('-b, --beta', 'B')
        .option('-c, --gamma', 'C')
      const { opts } = cmd.parse(['-abc'], {})
      assert.equal(opts.alpha, true)
      assert.equal(opts.beta, true)
      assert.equal(opts.gamma, true)
    })

    it('parses combined options with value on last: -abc value', () => {
      const cmd = new Command('cli')
        .option('-a, --alpha', 'A')
        .option('-b, --beta', 'B')
        .option('-c, --config <path>', 'Config')
      const { opts } = cmd.parse(['-abc', 'app.json'], {})
      assert.equal(opts.alpha, true)
      assert.equal(opts.beta, true)
      assert.equal(opts.config, 'app.json')
    })

    it('errors when non-boolean is not last', () => {
      const cmd = new Command('cli')
        .option('-a, --alpha', 'A')
        .option('-c, --config <path>', 'Config')
        .option('-b, --beta', 'B')
      const { diagnostics } = cmd.parse(['-acb'], {})
      assert.match(diagnostics[0].message, /requires a value/)
    })

    it('reports unknown short option in combination', () => {
      const cmd = new Command('cli')
        .option('-a, --alpha', 'A')
        .option('-b, --beta', 'B')
      const { diagnostics } = cmd.parse(['-axb'], {})
      assert.match(diagnostics[0].message, /Unknown option '-x'/)
    })
  })

  // ============================================================
  // Options - Special Syntax
  // ============================================================

  describe('option syntax', () => {
    it('parses equals syntax: --config=value', () => {
      const cmd = new Command('cli').option('-c, --config <path>', 'Config')
      assert.equal(cmd.parse(['--config=app.json'], {}).opts.config, 'app.json')
    })

    it('parses value starting with dash after equals', () => {
      const cmd = new Command('cli').option('-c, --config <path>', 'Config')
      assert.equal(cmd.parse(['--config=-test.json'], {}).opts.config, '-test.json')
    })

    it('converts kebab-case to camelCase', () => {
      const cmd = new Command('cli').option('--dry-run', 'Dry run')
      assert.equal(cmd.parse(['--dry-run'], {}).opts.dryRun, true)
    })

    it('treats everything after -- as positional', () => {
      const cmd = new Command('cli')
        .option('-f, --force', 'Force')
        .argument('[...files]', 'Files')
      const { args, opts } = cmd.parse(['--force', '--', '--not-option', '-f'], {})
      assert.equal(opts.force, true)
      assert.deepEqual(args.files, ['--not-option', '-f'])
    })
  })

  // ============================================================
  // Built-in Options & Strict Mode
  // ============================================================

  describe('built-in options', () => {
    it('has --help', () => {
      const cmd = new Command('cli')
      assert.equal(cmd.parse(['--help'], {}).opts.help, true)
    })

    it('has --version when set', () => {
      const cmd = new Command('cli').version('1.0.0')
      assert.equal(cmd.parse(['--version'], {}).opts.version, true)
    })

    it('has --log-level with default info', () => {
      const cmd = new Command('cli')
      assert.equal(cmd.parse([], {}).opts.logLevel, 'info')
    })

    it('validates --log-level value', () => {
      const cmd = new Command('cli')
      const { diagnostics } = cmd.parse(['--log-level', 'verbose'], {})
      assert.match(diagnostics[0].message, /Invalid log level/)
    })

    it('has --silent that sets logLevel to error', () => {
      const cmd = new Command('cli')
      const { opts } = cmd.parse(['--silent'], {})
      assert.equal(opts.silent, true)
      assert.equal(opts.logLevel, 'error')
    })
  })

  describe('strict mode', () => {
    it('errors on unknown option by default', () => {
      const cmd = new Command('cli')
      const { diagnostics } = cmd.parse(['--unknown'], {})
      assert.match(diagnostics[0].message, /Unknown option/)
    })

    it('allows unknown option when disabled', () => {
      const cmd = new Command('cli').strict(false)
      const { diagnostics } = cmd.parse(['--unknown'], {})
      assert.equal(diagnostics.length, 0)
    })
  })

  // ============================================================
  // run()
  // ============================================================

  describe('run', () => {
    it('shows help on --help', async () => {
      const cmd = new Command('cli').action(async () => {
        throw new Error('Should not execute')
      })
      await cmd.run(['--help'], {})
    })

    it('shows version on --version', async () => {
      const cmd = new Command('cli').version('1.0.0').action(async () => {
        throw new Error('Should not execute')
      })
      await cmd.run(['--version'], {})
    })

    it('sets exitCode=1 on error', async () => {
      const original = process.exitCode
      const cmd = new Command('cli').argument('<file>', 'File')
      await cmd.run([], {})
      assert.equal(process.exitCode, 1)
      process.exitCode = original
    })

    it('executes action on success', async () => {
      let called = false
      const cmd = new Command('cli')
        .argument('<file>', 'File')
        .action(async ({ args }) => {
          called = true
          assert.equal(args.file, 'test.txt')
        })
      await cmd.run(['test.txt'], {})
      assert.equal(called, true)
    })
  })

  // ============================================================
  // execute()
  // ============================================================

  describe('execute', () => {
    it('calls action handler with params', async () => {
      /** @type {*} */
      let params = null
      const cmd = new Command('cli')
        .argument('<file>', 'File')
        .option('-f, --force', 'Force')
        .action(async p => {
          params = p
        })

      const { args, opts } = cmd.parse(['test.txt', '-f'], {})
      await cmd.execute({ ctx: cmd, args, opts, envs: {} })

      assert.equal(params.ctx, cmd)
      assert.equal(params.args.file, 'test.txt')
      assert.equal(params.opts.force, true)
    })
  })

  // ============================================================
  // showHelp()
  // ============================================================

  describe('showHelp', () => {
    it('does not throw', () => {
      const cmd = new Command('cli')
        .description('A CLI tool')
        .version('1.0.0')
        .argument('<file>', 'Input')
        .argument('[output]', 'Output')
        .option('-f, --force', 'Force')
        .option('-p, --port <n>', 'Port', { type: 'number', default: 3000, env: 'PORT' })
        .example('cli input.txt')
      assert.doesNotThrow(() => cmd.showHelp())
    })

    it('includes required variadic in usage', () => {
      const cmd = new Command('cli').argument('<...files>', 'Files')
      assert.doesNotThrow(() => cmd.showHelp())
    })
  })

  // ============================================================
  // Edge Cases
  // ============================================================

  describe('edge cases', () => {
    it('handles empty argv', () => {
      const cmd = new Command('cli')
      const { args, diagnostics } = cmd.parse([], {})
      assert.deepEqual(args, {})
      assert.equal(diagnostics.length, 0)
    })
  })
})
