import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { parse, stringify } from './env.mjs'

describe('env', () => {
  // ====================
  // parse
  // ====================

  describe('parse', () => {
    it('parses simple key=value pairs', () => {
      const env = parse('NAME=hello\nPORT=3000')
      assert.equal(env.NAME, 'hello')
      assert.equal(env.PORT, 3000)
    })

    it('handles empty content', () => {
      assert.deepEqual(parse(''), {})
      assert.deepEqual(parse(undefined), {})
    })

    it('handles empty values', () => {
      const env = parse('EMPTY=')
      assert.equal(env.EMPTY, '')
    })

    it('ignores comments', () => {
      const env = parse('# comment\nNAME=test # inline')
      assert.equal(env.NAME, 'test')
      assert.equal(env['#'], undefined)
    })

    it('supports export prefix', () => {
      const env = parse('export NAME=test')
      assert.equal(env.NAME, 'test')
    })

    it('handles spaces around =', () => {
      const env = parse('NAME = test')
      assert.equal(env.NAME, 'test')
    })

    it('handles CRLF line endings', () => {
      const env = parse('A=1\r\nB=2\r\n')
      assert.equal(env.A, 1)
      assert.equal(env.B, 2)
    })

    // --------------------
    // Quoted values
    // --------------------

    it('parses single-quoted values', () => {
      const env = parse("NAME='hello world'")
      assert.equal(env.NAME, 'hello world')
    })

    it('parses double-quoted values', () => {
      const env = parse('NAME="hello world"')
      assert.equal(env.NAME, 'hello world')
    })

    it('parses backtick-quoted values', () => {
      const env = parse('NAME=`hello world`')
      assert.equal(env.NAME, 'hello world')
    })

    it('handles escape sequences in quotes', () => {
      const env = parse('MSG="line1\\nline2\\tindented\\rreturn"')
      assert.equal(env.MSG, 'line1\nline2\tindented\rreturn')
    })

    it('does not coerce types in quoted values', () => {
      const env = parse('NUM="42"\nBOOL="true"\nNUL="null"')
      assert.equal(env.NUM, '42')
      assert.equal(env.BOOL, 'true')
      assert.equal(env.NUL, 'null')
    })

    // --------------------
    // Type coercion
    // --------------------

    it('coerces null', () => {
      const env = parse('VALUE=null')
      assert.equal(env.VALUE, null)
    })

    it('coerces true', () => {
      const env = parse('VALUE=true')
      assert.equal(env.VALUE, true)
    })

    it('coerces false', () => {
      const env = parse('VALUE=false')
      assert.equal(env.VALUE, false)
    })

    it('coerces integers', () => {
      const env = parse('PORT=3000\nNEG=-42')
      assert.equal(env.PORT, 3000)
      assert.equal(env.NEG, -42)
    })

    it('coerces floats', () => {
      const env = parse('PI=3.14')
      assert.equal(env.PI, 3.14)
    })

    // --------------------
    // Variable interpolation
    // --------------------

    it('interpolates from parsed env', () => {
      const env = parse('BASE=/opt\nDATA=${env:BASE}/data')
      assert.equal(env.DATA, '/opt/data')
    })

    it('interpolates from input env', () => {
      const env = parse('PATH=${env:BASE}/bin', { BASE: '/home/test' })
      assert.equal(env.PATH, '/home/test/bin')
      assert.equal(env.BASE, '/home/test')
    })

    it('handles missing interpolation vars', () => {
      const env = parse('PATH=${env:__MISSING__}/bin')
      assert.equal(env.PATH, '/bin')
    })

    it('handles null value in interpolation', () => {
      const env = parse('BASE=null\nPATH=${env:BASE}/bin')
      assert.equal(env.BASE, null)
      assert.equal(env.PATH, '/bin')
    })

    // --------------------
    // Merge behavior
    // --------------------

    it('does not mutate input env', () => {
      const existing = { NAME: 'old', PORT: 8080 }
      const result = parse('NAME=new', existing)
      assert.equal(existing.NAME, 'old')
      assert.equal(existing.PORT, 8080)
      assert.equal(result.NAME, 'new')
      assert.equal(result.PORT, 8080)
    })
  })

  // ====================
  // stringify
  // ====================

  describe('stringify', () => {
    it('stringifies simple values', () => {
      const result = stringify({ NAME: 'test', PORT: 3000 })
      assert.equal(result, 'NAME=test\nPORT=3000\n')
    })

    it('stringifies boolean values', () => {
      const result = stringify({ DEBUG: true, VERBOSE: false })
      assert.equal(result, 'DEBUG=true\nVERBOSE=false\n')
    })

    it('stringifies null', () => {
      const result = stringify({ VALUE: null })
      assert.equal(result, 'VALUE=null\n')
    })

    it('quotes values with spaces', () => {
      const result = stringify({ MSG: 'hello world' })
      assert.equal(result, 'MSG="hello world"\n')
    })

    it('quotes values with quotes', () => {
      const result = stringify({ MSG: 'say "hello"' })
      assert.equal(result, 'MSG="say \\"hello\\""\n')
    })

    it('quotes values with tabs', () => {
      const result = stringify({ MSG: 'col1\tcol2' })
      assert.equal(result, 'MSG="col1\\tcol2"\n')
    })

    it('quotes values with newlines', () => {
      const result = stringify({ MSG: 'line1\nline2' })
      assert.equal(result, 'MSG="line1\\nline2"\n')
    })

    it('excludes specified keys', () => {
      const result = stringify({ A: 1, B: 2, C: 3 }, { exclude: ['B'] })
      assert.equal(result, 'A=1\nC=3\n')
    })

    it('returns empty string for empty object', () => {
      assert.equal(stringify({}), '')
    })
  })
})
