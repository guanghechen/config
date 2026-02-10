import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { Command, CommanderError, DefaultReporter } from './commander.mjs'

/** Create a mock reporter for testing */
function createReporter() {
  return new DefaultReporter()
}

describe('Command', () => {
  // ============================================================
  // Constructor & Properties
  // ============================================================

  describe('constructor', () => {
    it('creates command with config', () => {
      const cmd = new Command({ name: 'my-cli', description: 'A CLI tool', version: '1.0.0' })
      assert.equal(cmd.name, 'my-cli')
      assert.equal(cmd.description, 'A CLI tool')
      assert.equal(cmd.version, '1.0.0')
    })

    it('creates command with minimal config', () => {
      const cmd = new Command({ description: 'A CLI tool' })
      assert.equal(cmd.name, '')
      assert.equal(cmd.description, 'A CLI tool')
      assert.equal(cmd.version, undefined)
    })
  })

  // ============================================================
  // Fluent API
  // ============================================================

  describe('fluent API', () => {
    it('supports method chaining', () => {
      const cmd = new Command({ name: 'cli', description: 'Test CLI', version: '1.0.0' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
        .action(async () => {})
      assert.equal(cmd.name, 'cli')
      assert.equal(cmd.arguments.length, 1)
      assert.equal(cmd.options.length, 1)
    })
  })

  // ============================================================
  // Arguments
  // ============================================================

  describe('argument', () => {
    it('parses required argument', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'file', kind: 'required', description: 'File' })
      const { args } = cmd.parse(['input.txt'])
      assert.equal(args.file, 'input.txt')
    })

    it('throws on missing required argument via parse()', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'file', kind: 'required', description: 'File' })
      assert.throws(() => cmd.parse([]), CommanderError)
    })

    it('parses optional argument', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'file', kind: 'optional', description: 'File' })
      const { args } = cmd.parse([])
      assert.equal(args.file, undefined)
    })

    it('parses multiple arguments', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .argument({ name: 'source', kind: 'required', description: 'Source' })
        .argument({ name: 'dest', kind: 'required', description: 'Dest' })
      const { args } = cmd.parse(['a.txt', 'b.txt'])
      assert.equal(args.source, 'a.txt')
      assert.equal(args.dest, 'b.txt')
    })

    it('parses variadic argument', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'files', kind: 'variadic', description: 'Files' })
      const { args } = cmd.parse(['a.txt', 'b.txt'])
      assert.deepEqual(args.files, ['a.txt', 'b.txt'])
    })

    it('parses argument with type number', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'port', kind: 'required', type: 'number', description: 'Port' })
      const { args } = cmd.parse(['3000'])
      assert.equal(args.port, 3000)
    })

    it('throws on invalid number argument', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'port', kind: 'required', type: 'number', description: 'Port' })
      assert.throws(() => cmd.parse(['abc']), CommanderError)
    })

    it('applies argument coerce', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .argument({ name: 'port', kind: 'required', coerce: v => parseInt(v, 10) * 2, description: 'Port' })
      const { args } = cmd.parse(['100'])
      assert.equal(args.port, 200)
    })

    it('parses optional argument with default', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .argument({ name: 'env', kind: 'optional', default: 'development', description: 'Env' })
      const { args } = cmd.parse([])
      assert.equal(args.env, 'development')
    })

    it('throws on too many arguments', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
      assert.throws(() => cmd.parse(['a.txt', 'b.txt']), CommanderError)
    })

    it('throws on invalid argument config without name', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.argument({ name: '', kind: 'required', description: 'Test' }), /must have a name/)
    })

    it('throws on required argument with default', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.argument({ name: 'file', kind: 'required', default: 'test', description: 'Test' }), /cannot have a default/)
    })

    it('throws on multiple variadic arguments', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'files', kind: 'variadic', description: 'Files' })
      assert.throws(() => cmd.argument({ name: 'more', kind: 'variadic', description: 'More' }), /only one variadic/)
    })
  })

  // ============================================================
  // Options - Basic Types
  // ============================================================

  describe('option', () => {
    it('parses boolean option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
      assert.equal(cmd.parse(['--force']).opts.force, true)
      assert.equal(cmd.parse(['-f']).opts.force, true)
    })

    it('parses string option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.equal(cmd.parse(['--config', 'app.json']).opts.config, 'app.json')
      assert.equal(cmd.parse(['-c', 'app.json']).opts.config, 'app.json')
    })

    it('parses number option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'port', short: 'p', type: 'number', description: 'Port' })
      assert.equal(cmd.parse(['--port', '3000']).opts.port, 3000)
      assert.equal(cmd.parse(['-p', '8080']).opts.port, 8080)
    })

    it('parses string array option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'include', short: 'i', type: 'string[]', description: 'Dirs' })
      const { opts } = cmd.parse(['--include', 'src', '--include', 'lib'])
      assert.deepEqual(opts.include, ['src', 'lib'])
    })

    it('parses number array option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'ports', short: 'P', type: 'number[]', description: 'Ports' })
      const { opts } = cmd.parse(['--ports', '80', '--ports', '443'])
      assert.deepEqual(opts.ports, [80, 443])
    })

    it('throws on invalid number value', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'port', short: 'p', type: 'number', description: 'Port' })
      assert.throws(() => cmd.parse(['--port', 'abc']), CommanderError)
    })

    it('throws on invalid number array value', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'ports', short: 'P', type: 'number[]', description: 'Ports' })
      assert.throws(() => cmd.parse(['--ports', 'abc']), CommanderError)
    })

    it('throws on missing option value', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.throws(() => cmd.parse(['--config']), CommanderError)
    })
  })

  // ============================================================
  // Options - Default
  // ============================================================

  describe('option default', () => {
    it('uses default value', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'port', short: 'p', type: 'number', default: 3000, description: 'Port' })
      assert.equal(cmd.parse([]).opts.port, 3000)
    })

    it('argv overrides default', async () => {
      let capturedOpts = {}
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'port', short: 'p', type: 'number', default: 3000, description: 'Port' })
        .action(async ({ opts }) => {
          capturedOpts = opts
        })

      // Default only
      await cmd.run({ argv: [], envs: {}, reporter: createReporter() })
      assert.equal(capturedOpts.port, 3000)

      // Argv overrides default
      await cmd.run({ argv: ['--port', '9000'], envs: {}, reporter: createReporter() })
      assert.equal(capturedOpts.port, 9000)
    })
  })

  // ============================================================
  // Options - Override Semantics
  // ============================================================

  describe('option override', () => {
    it('scalar option: later wins', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'port', short: 'p', type: 'number', description: 'Port' })
      assert.equal(cmd.parse(['--port', '3000', '--port', '8080']).opts.port, 8080)
    })

    it('array option: accumulates', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'include', short: 'i', type: 'string[]', description: 'Dirs' })
      const { opts } = cmd.parse(['--include', 'a', '--include', 'b'])
      assert.deepEqual(opts.include, ['a', 'b'])
    })
  })

  // ============================================================
  // Options - Negatable
  // ============================================================

  describe('negatable option', () => {
    it('negates with --no-prefix', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'color', type: 'boolean', description: 'Color' })
      assert.equal(cmd.parse(['--no-color']).opts.color, false)
    })

    it('later wins: --flag then --no-flag', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'color', type: 'boolean', description: 'Color' })
      assert.equal(cmd.parse(['--color', '--no-color']).opts.color, false)
    })

    it('later wins: --no-flag then --flag', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'color', type: 'boolean', description: 'Color' })
      assert.equal(cmd.parse(['--no-color', '--color']).opts.color, true)
    })
  })

  // ============================================================
  // Options - Short Option Syntax
  // ============================================================

  describe('short option combination', () => {
    it('parses combined boolean options: -abc', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
        .option({ long: 'gamma', short: 'c', type: 'boolean', description: 'C' })
      const { opts } = cmd.parse(['-abc'])
      assert.equal(opts.alpha, true)
      assert.equal(opts.beta, true)
      assert.equal(opts.gamma, true)
    })

    it('parses combined options with value on last: -abc value', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
        .option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      const { opts } = cmd.parse(['-abc', 'app.json'])
      assert.equal(opts.alpha, true)
      assert.equal(opts.beta, true)
      assert.equal(opts.config, 'app.json')
    })

    it('throws when non-boolean is not last', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
      assert.throws(() => cmd.parse(['-acb']), CommanderError)
    })

    it('throws on unknown short option in combination', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
      assert.throws(() => cmd.parse(['-axb']), CommanderError)
    })
  })

  // ============================================================
  // Options - Special Syntax
  // ============================================================

  describe('option syntax', () => {
    it('parses equals syntax: --config=value', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.equal(cmd.parse(['--config=app.json']).opts.config, 'app.json')
    })

    it('parses value starting with dash after equals', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.equal(cmd.parse(['--config=-test.json']).opts.config, '-test.json')
    })

    it('treats everything after -- as positional', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
        .argument({ name: 'files', kind: 'variadic', description: 'Files' })
      const { args, opts, rawArgs } = cmd.parse(['--force', '--', '--not-option', '-f'])
      assert.equal(opts.force, true)
      assert.deepEqual(args.files, ['--not-option', '-f'])
      assert.deepEqual(rawArgs, ['--not-option', '-f'])
    })
  })

  // ============================================================
  // Built-in Options
  // ============================================================

  describe('built-in options', () => {
    it('has --help', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      // --help is handled in run(), not parse()
      // Just verify it doesn't throw
      assert.doesNotThrow(() => cmd.parse(['--help']))
    })

    it('has --version when set', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI', version: '1.0.0' })
      // --version is handled in run(), not parse()
      assert.doesNotThrow(() => cmd.parse(['--version']))
    })

    it('throws on unknown option by default', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.parse(['--unknown']), CommanderError)
    })
  })

  // ============================================================
  // run()
  // ============================================================

  describe('run', () => {
    it('executes action on success', async () => {
      let called = false
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .action(async ({ args }) => {
          called = true
          assert.equal(args.file, 'test.txt')
        })
      await cmd.run({ argv: ['--', 'test.txt'], envs: {}, reporter: createReporter() })
      assert.equal(called, true)
    })

    it('passes ctx, opts, args to action', async () => {
      /** @type {*} */
      let params = null
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
        .action(async p => {
          params = p
        })

      await cmd.run({ argv: ['-f', '--', 'test.txt'], envs: {}, reporter: createReporter() })

      assert.equal(params.ctx.cmd, cmd)
      assert.equal(params.args.file, 'test.txt')
      assert.equal(params.opts.force, true)
      assert.deepEqual(params.rawArgs, ['test.txt'])
    })
  })

  // ============================================================
  // formatHelp()
  // ============================================================

  describe('formatHelp', () => {
    it('includes description', () => {
      const cmd = new Command({ name: 'cli', description: 'A CLI tool' })
      const help = cmd.formatHelp()
      assert.match(help, /A CLI tool/)
    })

    it('includes usage line', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      const help = cmd.formatHelp()
      assert.match(help, /Usage: cli/)
    })

    it('includes options', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'force', short: 'f', type: 'boolean', description: 'Force operation' })
      const help = cmd.formatHelp()
      assert.match(help, /Options:/)
      assert.match(help, /--force/)
      assert.match(help, /-f/)
    })

    it('includes variadic argument in usage', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).argument({ name: 'files', kind: 'variadic', description: 'Files' })
      const help = cmd.formatHelp()
      assert.match(help, /\[files\.\.\.\]/)
    })
  })

  // ============================================================
  // Subcommands
  // ============================================================

  describe('subcommand', () => {
    it('registers subcommand', () => {
      const sub = new Command({ description: 'Subcommand' })
      const cmd = new Command({ name: 'cli', description: 'CLI' }).subcommand('sub', sub)
      const help = cmd.formatHelp()
      assert.match(help, /Commands:/)
      assert.match(help, /sub/)
    })

    it('routes to subcommand', async () => {
      let called = false
      const sub = new Command({ description: 'Subcommand' }).action(async () => {
        called = true
      })
      const cmd = new Command({ name: 'cli', description: 'CLI' }).subcommand('sub', sub)
      await cmd.run({ argv: ['sub'], envs: {}, reporter: createReporter() })
      assert.equal(called, true)
    })

    it('passes remaining args to subcommand', async () => {
      /** @type {Record<string, unknown>} */
      let capturedArgs = {}
      const sub = new Command({ description: 'Subcommand' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .action(async ({ args }) => {
          capturedArgs = args
        })
      const cmd = new Command({ name: 'cli', description: 'CLI' }).subcommand('sub', sub)
      await cmd.run({ argv: ['sub', '--', 'test.txt'], envs: {}, reporter: createReporter() })
      assert.equal(capturedArgs.file, 'test.txt')
    })

    it('supports subcommand aliases', async () => {
      let called = false
      const sub = new Command({ description: 'Subcommand' }).action(async () => {
        called = true
      })
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .subcommand('generate', sub)
        .subcommand('gen', sub)
      await cmd.run({ argv: ['gen'], envs: {}, reporter: createReporter() })
      assert.equal(called, true)
    })
  })

  // ============================================================
  // shift()
  // ============================================================

  describe('shift', () => {
    it('consumes recognized options', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
        .option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      const result = cmd.shift(['--force', '-c', 'app.json', '--unknown'])
      assert.equal(result.opts.force, true)
      assert.equal(result.opts.config, 'app.json')
      assert.deepEqual(result.remaining, ['--unknown'])
    })

    it('passes unrecognized options to remaining', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'verbose', short: 'v', type: 'boolean', description: 'Verbose' })
      const result = cmd.shift(['--verbose', '--other', 'value'])
      assert.equal(result.opts.verbose, true)
      assert.deepEqual(result.remaining, ['--other', 'value'])
    })
  })

  // ============================================================
  // CommanderError
  // ============================================================

  describe('CommanderError', () => {
    it('has kind and commandPath', () => {
      const err = new CommanderError('UnknownOption', 'Unknown option', 'cli')
      assert.equal(err.kind, 'UnknownOption')
      assert.equal(err.commandPath, 'cli')
    })

    it('formats error message', () => {
      const err = new CommanderError('UnknownOption', 'Unknown option', 'cli')
      const formatted = err.format()
      assert.match(formatted, /Error: Unknown option/)
      assert.match(formatted, /Run "cli --help"/)
    })
  })

  // ============================================================
  // DefaultReporter
  // ============================================================

  describe('DefaultReporter', () => {
    it('has debug, info, warn, error methods', () => {
      const reporter = new DefaultReporter()
      assert.equal(typeof reporter.debug, 'function')
      assert.equal(typeof reporter.info, 'function')
      assert.equal(typeof reporter.warn, 'function')
      assert.equal(typeof reporter.error, 'function')
    })
  })

  // ============================================================
  // Edge Cases
  // ============================================================

  describe('edge cases', () => {
    it('handles empty argv', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      const { args, rawArgs } = cmd.parse([])
      assert.deepEqual(args, {})
      assert.deepEqual(rawArgs, [])
    })

    it('throws on duplicate option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' }).option({ long: 'force', type: 'boolean', description: 'Force' })
      assert.throws(() => cmd.option({ long: 'force', type: 'boolean', description: 'Force' }), /already defined/)
    })

    it('throws on option without long name', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.option({ long: '', type: 'boolean', description: 'Test' }), /must have a long name/)
    })

    it('throws on option starting with no-', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.option({ long: 'no-force', type: 'boolean', description: 'Test' }), /cannot start with "no-"/)
    })
  })

  // ============================================================
  // Option Features
  // ============================================================

  describe('option features', () => {
    it('validates choices', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'level', type: 'string', choices: ['debug', 'info', 'warn'], description: 'Log level' })
      assert.throws(() => cmd.parse(['--level', 'invalid']), CommanderError)
    })

    it('accepts valid choice', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'level', type: 'string', choices: ['debug', 'info', 'warn'], description: 'Log level' })
      const { opts } = cmd.parse(['--level', 'info'])
      assert.equal(opts.level, 'info')
    })

    it('applies coerce function', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'date', type: 'string', coerce: v => new Date(v), description: 'Date' })
      const { opts } = cmd.parse(['--date', '2024-01-01'])
      assert.ok(opts.date instanceof Date)
    })

    it('validates required option', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({ long: 'config', type: 'string', required: true, description: 'Config' })
      assert.throws(() => cmd.parse([]), CommanderError)
    })

    it('throws on required + default conflict', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.option({ long: 'config', type: 'string', required: true, default: 'test', description: 'Config' }), /cannot be both required and have a default/)
    })

    it('throws on boolean + required conflict', () => {
      const cmd = new Command({ name: 'cli', description: 'CLI' })
      assert.throws(() => cmd.option({ long: 'force', type: 'boolean', required: true, description: 'Force' }), /boolean option.*cannot be required/)
    })
  })

  // ============================================================
  // Apply Callback
  // ============================================================

  describe('option apply callback', () => {
    it('calls apply with value and context', async () => {
      /** @type {*} */
      let appliedValue = null
      /** @type {*} */
      let appliedCtx = null

      const cmd = new Command({ name: 'cli', description: 'CLI' })
        .option({
          long: 'verbose',
          type: 'boolean',
          description: 'Verbose',
          apply: (value, ctx) => {
            appliedValue = value
            appliedCtx = ctx
          },
        })
        .action(async () => {})

      await cmd.run({ argv: ['--verbose'], envs: { TEST: 'value' }, reporter: createReporter() })

      assert.equal(appliedValue, true)
      assert.equal(appliedCtx.envs.TEST, 'value')
      assert.ok(appliedCtx.reporter)
    })
  })
})
