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
      const cmd = new Command({ name: 'cli' })
      assert.equal(cmd.name, 'cli')
      assert.equal(cmd.description, undefined)
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
      const cmd = new Command({ name: 'cli' }).argument({ name: 'file', kind: 'required', description: 'File' })
      const { args } = cmd.parse(['input.txt'])
      assert.equal(args.file, 'input.txt')
    })

    it('throws on missing required argument via run()', async () => {
      let errorMsg = ''
      const reporter = {
        debug() {},
        info() {},
        warn() {},
        error(msg) {
          errorMsg = msg
        },
      }
      const cmd = new Command({ name: 'cli' }).argument({ name: 'file', kind: 'required', description: 'File' })
      await cmd.run({ argv: [], envs: {}, reporter })
      assert.match(errorMsg, /Missing required argument/)
    })

    it('parses optional argument', () => {
      const cmd = new Command({ name: 'cli' }).argument({ name: 'file', kind: 'optional', description: 'File' })
      const { args } = cmd.parse([])
      assert.equal(args.file, undefined)
    })

    it('parses optional argument with default', () => {
      const cmd = new Command({ name: 'cli' }).argument({ name: 'format', kind: 'optional', default: 'json', description: 'Format' })
      const { args } = cmd.parse([])
      assert.equal(args.format, 'json')
    })

    it('parses multiple arguments', () => {
      const cmd = new Command({ name: 'cli' })
        .argument({ name: 'source', kind: 'required', description: 'Source' })
        .argument({ name: 'dest', kind: 'required', description: 'Dest' })
      const { args } = cmd.parse(['a.txt', 'b.txt'])
      assert.equal(args.source, 'a.txt')
      assert.equal(args.dest, 'b.txt')
    })

    it('parses variadic argument', () => {
      const cmd = new Command({ name: 'cli' }).argument({ name: 'files', kind: 'variadic', description: 'Files' })
      const { args } = cmd.parse(['a.txt', 'b.txt'])
      assert.deepEqual(args.files, ['a.txt', 'b.txt'])
    })

    it('throws on invalid argument config without name', () => {
      const cmd = new Command({ name: 'cli' })
      assert.throws(() => cmd.argument({ name: '', kind: 'required' }), /must have a name/)
    })

    it('throws on multiple variadic arguments', () => {
      const cmd = new Command({ name: 'cli' }).argument({ name: 'files', kind: 'variadic', description: 'Files' })
      assert.throws(() => cmd.argument({ name: 'more', kind: 'variadic', description: 'More' }), /Only one variadic/)
    })
  })

  // ============================================================
  // Options - Basic Types
  // ============================================================

  describe('option', () => {
    it('parses boolean option', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
      assert.equal(cmd.parse(['--force']).opts.force, true)
      assert.equal(cmd.parse(['-f']).opts.force, true)
    })

    it('parses string option', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.equal(cmd.parse(['--config', 'app.json']).opts.config, 'app.json')
      assert.equal(cmd.parse(['-c', 'app.json']).opts.config, 'app.json')
    })

    it('parses number option', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'port', short: 'p', type: 'number', description: 'Port' })
      assert.equal(cmd.parse(['--port', '3000']).opts.port, 3000)
      assert.equal(cmd.parse(['-p', '8080']).opts.port, 8080)
    })

    it('parses string array option', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'include', short: 'i', type: 'string[]', description: 'Dirs' })
      const { opts } = cmd.parse(['--include', 'src', '--include', 'lib'])
      assert.deepEqual(opts.include, ['src', 'lib'])
    })

    it('parses number array option', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'ports', short: 'P', type: 'number[]', description: 'Ports' })
      const { opts } = cmd.parse(['--ports', '80', '--ports', '443'])
      assert.deepEqual(opts.ports, [80, 443])
    })

    it('throws on invalid number value', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'port', short: 'p', type: 'number', description: 'Port' })
      assert.throws(() => cmd.parse(['--port', 'abc']), CommanderError)
    })

    it('throws on invalid number array value', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'ports', short: 'P', type: 'number[]', description: 'Ports' })
      assert.throws(() => cmd.parse(['--ports', 'abc']), CommanderError)
    })

    it('throws on missing option value', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.throws(() => cmd.parse(['--config']), CommanderError)
    })
  })

  // ============================================================
  // Options - Default & Environment Variables
  // ============================================================

  describe('option default & env', () => {
    it('uses default value', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'port', short: 'p', type: 'number', default: 3000, description: 'Port' })
      assert.equal(cmd.parse([]).opts.port, 3000)
    })

    it('uses env value via run()', async () => {
      let capturedOpts = {}
      const cmd = new Command({ name: 'cli' })
        .option({ long: 'port', short: 'p', type: 'number', env: 'PORT', description: 'Port' })
        .action(async ({ opts }) => {
          capturedOpts = opts
        })
      await cmd.run({ argv: [], envs: { PORT: '8080' }, reporter: createReporter() })
      assert.equal(capturedOpts.port, 8080)
    })

    it('follows priority: default < env < argv', async () => {
      let capturedOpts = {}
      const cmd = new Command({ name: 'cli' })
        .option({ long: 'port', short: 'p', type: 'number', default: 3000, env: 'PORT', description: 'Port' })
        .action(async ({ opts }) => {
          capturedOpts = opts
        })

      // Default only
      await cmd.run({ argv: [], envs: {}, reporter: createReporter() })
      assert.equal(capturedOpts.port, 3000)

      // Env overrides default
      await cmd.run({ argv: [], envs: { PORT: '8080' }, reporter: createReporter() })
      assert.equal(capturedOpts.port, 8080)

      // Argv overrides env
      await cmd.run({ argv: ['--port', '9000'], envs: { PORT: '8080' }, reporter: createReporter() })
      assert.equal(capturedOpts.port, 9000)
    })
  })

  // ============================================================
  // Options - Override Semantics
  // ============================================================

  describe('option override', () => {
    it('scalar option: later wins', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'port', short: 'p', type: 'number', description: 'Port' })
      assert.equal(cmd.parse(['--port', '3000', '--port', '8080']).opts.port, 8080)
    })

    it('array option: accumulates', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'include', short: 'i', type: 'string[]', description: 'Dirs' })
      const { opts } = cmd.parse(['--include', 'a', '--include', 'b'])
      assert.deepEqual(opts.include, ['a', 'b'])
    })
  })

  // ============================================================
  // Options - Negatable
  // ============================================================

  describe('negatable option', () => {
    it('negates with --no-prefix', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'color', type: 'boolean', description: 'Color' })
      assert.equal(cmd.parse(['--no-color']).opts.color, false)
    })

    it('later wins: --flag then --no-flag', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'color', type: 'boolean', description: 'Color' })
      assert.equal(cmd.parse(['--color', '--no-color']).opts.color, false)
    })

    it('later wins: --no-flag then --flag', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'color', type: 'boolean', description: 'Color' })
      assert.equal(cmd.parse(['--no-color', '--color']).opts.color, true)
    })
  })

  // ============================================================
  // Options - Short Option Syntax
  // ============================================================

  describe('short option combination', () => {
    it('parses combined boolean options: -abc', () => {
      const cmd = new Command({ name: 'cli' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
        .option({ long: 'gamma', short: 'c', type: 'boolean', description: 'C' })
      const { opts } = cmd.parse(['-abc'])
      assert.equal(opts.alpha, true)
      assert.equal(opts.beta, true)
      assert.equal(opts.gamma, true)
    })

    it('parses combined options with value on last: -abc value', () => {
      const cmd = new Command({ name: 'cli' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
        .option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      const { opts } = cmd.parse(['-abc', 'app.json'])
      assert.equal(opts.alpha, true)
      assert.equal(opts.beta, true)
      assert.equal(opts.config, 'app.json')
    })

    it('throws when non-boolean is not last', () => {
      const cmd = new Command({ name: 'cli' })
        .option({ long: 'alpha', short: 'a', type: 'boolean', description: 'A' })
        .option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
        .option({ long: 'beta', short: 'b', type: 'boolean', description: 'B' })
      assert.throws(() => cmd.parse(['-acb']), CommanderError)
    })

    it('throws on unknown short option in combination', () => {
      const cmd = new Command({ name: 'cli' })
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
      const cmd = new Command({ name: 'cli' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.equal(cmd.parse(['--config=app.json']).opts.config, 'app.json')
    })

    it('parses value starting with dash after equals', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'config', short: 'c', type: 'string', description: 'Config' })
      assert.equal(cmd.parse(['--config=-test.json']).opts.config, '-test.json')
    })

    it('converts kebab-case to camelCase', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'dry-run', type: 'boolean', description: 'Dry run' })
      assert.equal(cmd.parse(['--dry-run']).opts.dryRun, true)
    })

    it('treats everything after -- as positional', () => {
      const cmd = new Command({ name: 'cli' })
        .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
        .argument({ name: 'files', kind: 'variadic', description: 'Files' })
      const { args, opts } = cmd.parse(['--force', '--', '--not-option', '-f'])
      assert.equal(opts.force, true)
      assert.deepEqual(args.files, ['--not-option', '-f'])
    })
  })

  // ============================================================
  // Built-in Options
  // ============================================================

  describe('built-in options', () => {
    it('has --help', () => {
      const cmd = new Command({ name: 'cli' })
      // --help is handled in run(), not parse()
      // Just verify it doesn't throw
      assert.doesNotThrow(() => cmd.parse(['--help']))
    })

    it('has --version when set', () => {
      const cmd = new Command({ name: 'cli', version: '1.0.0' })
      // --version is handled in run(), not parse()
      assert.doesNotThrow(() => cmd.parse(['--version']))
    })

    it('throws on unknown option by default', () => {
      const cmd = new Command({ name: 'cli' })
      assert.throws(() => cmd.parse(['--unknown']), CommanderError)
    })
  })

  // ============================================================
  // run()
  // ============================================================

  describe('run', () => {
    it('shows help on --help', async () => {
      let output = ''
      const reporter = {
        debug() {},
        info(msg) {
          output = msg
        },
        warn() {},
        error() {},
      }
      const cmd = new Command({ name: 'cli', description: 'A CLI tool' }).action(async () => {
        throw new Error('Should not execute')
      })
      await cmd.run({ argv: ['--help'], envs: {}, reporter })
      assert.match(output, /Usage:/)
    })

    it('shows version on --version', async () => {
      let output = ''
      const reporter = {
        debug() {},
        info(msg) {
          output = msg
        },
        warn() {},
        error() {},
      }
      const cmd = new Command({ name: 'cli', version: '1.0.0' }).action(async () => {
        throw new Error('Should not execute')
      })
      await cmd.run({ argv: ['--version'], envs: {}, reporter })
      assert.equal(output, '1.0.0')
    })

    it('sets exitCode=1 on error', async () => {
      const original = process.exitCode
      const reporter = {
        debug() {},
        info() {},
        warn() {},
        error() {},
      }
      const cmd = new Command({ name: 'cli' }).argument({ name: 'file', kind: 'required', description: 'File' })
      await cmd.run({ argv: [], envs: {}, reporter })
      assert.equal(process.exitCode, 1)
      process.exitCode = original
    })

    it('executes action on success', async () => {
      let called = false
      const cmd = new Command({ name: 'cli' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .action(async ({ args }) => {
          called = true
          assert.equal(args.file, 'test.txt')
        })
      await cmd.run({ argv: ['test.txt'], envs: {}, reporter: createReporter() })
      assert.equal(called, true)
    })

    it('passes ctx, opts, args to action', async () => {
      /** @type {*} */
      let params = null
      const cmd = new Command({ name: 'cli' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .option({ long: 'force', short: 'f', type: 'boolean', description: 'Force' })
        .action(async p => {
          params = p
        })

      await cmd.run({ argv: ['test.txt', '-f'], envs: {}, reporter: createReporter() })

      assert.equal(params.ctx, cmd)
      assert.equal(params.args.file, 'test.txt')
      assert.equal(params.opts.force, true)
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
      const cmd = new Command({ name: 'cli' })
      const help = cmd.formatHelp()
      assert.match(help, /Usage: cli/)
    })

    it('includes arguments', () => {
      const cmd = new Command({ name: 'cli' }).argument({ name: 'file', kind: 'required', description: 'Input file' })
      const help = cmd.formatHelp()
      assert.match(help, /Arguments:/)
      assert.match(help, /file/)
    })

    it('includes options', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'force', short: 'f', type: 'boolean', description: 'Force operation' })
      const help = cmd.formatHelp()
      assert.match(help, /Options:/)
      assert.match(help, /--force/)
      assert.match(help, /-f/)
    })

    it('includes variadic argument in usage', () => {
      const cmd = new Command({ name: 'cli' }).argument({ name: 'files', kind: 'variadic', description: 'Files' })
      const help = cmd.formatHelp()
      assert.match(help, /\[\.\.\.files\]/)
    })
  })

  // ============================================================
  // Subcommands
  // ============================================================

  describe('subcommand', () => {
    it('registers subcommand', () => {
      const sub = new Command({ name: 'sub', description: 'Subcommand' })
      const cmd = new Command({ name: 'cli' }).subcommand('sub', sub)
      const help = cmd.formatHelp()
      assert.match(help, /Commands:/)
      assert.match(help, /sub/)
    })

    it('routes to subcommand', async () => {
      let called = false
      const sub = new Command({ name: 'sub', description: 'Subcommand' }).action(async () => {
        called = true
      })
      const cmd = new Command({ name: 'cli' }).subcommand('sub', sub)
      await cmd.run({ argv: ['sub'], envs: {}, reporter: createReporter() })
      assert.equal(called, true)
    })

    it('passes remaining args to subcommand', async () => {
      let capturedArgs = {}
      const sub = new Command({ name: 'sub', description: 'Subcommand' })
        .argument({ name: 'file', kind: 'required', description: 'File' })
        .action(async ({ args }) => {
          capturedArgs = args
        })
      const cmd = new Command({ name: 'cli' }).subcommand('sub', sub)
      await cmd.run({ argv: ['sub', 'test.txt'], envs: {}, reporter: createReporter() })
      assert.equal(capturedArgs.file, 'test.txt')
    })

    it('shows subcommand help', async () => {
      let output = ''
      const reporter = {
        debug() {},
        info(msg) {
          output = msg
        },
        warn() {},
        error() {},
      }
      const sub = new Command({ name: 'sub', description: 'Subcommand description' })
      const cmd = new Command({ name: 'cli' }).subcommand('sub', sub)
      await cmd.run({ argv: ['sub', '--help'], envs: {}, reporter })
      assert.match(output, /Subcommand description/)
    })
  })

  // ============================================================
  // CommanderError
  // ============================================================

  describe('CommanderError', () => {
    it('has kind and commandPath', () => {
      const err = new CommanderError('unknown_option', 'Unknown option', 'cli')
      assert.equal(err.kind, 'unknown_option')
      assert.equal(err.commandPath, 'cli')
    })

    it('formats error message', () => {
      const err = new CommanderError('unknown_option', 'Unknown option', 'cli')
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
      const cmd = new Command({ name: 'cli' })
      const { args } = cmd.parse([])
      assert.deepEqual(args, {})
    })

    it('throws on duplicate option', () => {
      const cmd = new Command({ name: 'cli' }).option({ long: 'force', type: 'boolean' })
      assert.throws(() => cmd.option({ long: 'force', type: 'boolean' }), /Duplicate option/)
    })

    it('throws on option without long name', () => {
      const cmd = new Command({ name: 'cli' })
      assert.throws(() => cmd.option({ long: '', type: 'boolean' }), /must have a long name/)
    })
  })
})
