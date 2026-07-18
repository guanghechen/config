#!/usr/bin/env node

import { serve } from '../src/server.mjs'
import { request } from '../src/client.mjs'

const [command, ...args] = process.argv.slice(2)

try {
  if (command === 'serve') {
    const port = readPortOption(args)
    await serve({ port })
  } else {
    const spec = resolveCommand(command, args)
    const response = await request(spec.capability, spec.options)
    process.stdout.write(`${JSON.stringify(response, null, 2)}\n`)
    if (!response.ok) process.exitCode = 1
  }
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`)
  process.exitCode = 1
}

function resolveCommand(command, args) {
  const pageId = args[0]
  const expectedDocumentId = readOption(args, '--document')
  const target = pageId ? { pageId, expectedDocumentId } : undefined

  switch (command) {
    case 'pages':
      return { capability: 'pages.list', options: {} }
    case 'active':
      return { capability: 'pages.resolveActive', options: {} }
    case 'describe':
      return requirePage('page.describe', target)
    case 'snapshot':
      return requirePage('dom.snapshot', target, { limit: readNumberOption(args, '--limit') })
    case 'query':
      return requirePage('dom.query', target, {
        selector: args[1],
        limit: readNumberOption(args, '--limit'),
      })
    case 'text':
      return requirePage('dom.getText', target, { snapshotId: args[1], ref: args[2] })
    case 'attributes':
      return requirePage('dom.getAttributes', target, { snapshotId: args[1], ref: args[2] })
    case 'bounds':
      return requirePage('dom.getBounds', target, { snapshotId: args[1], ref: args[2] })
    case 'cf-problems':
      return requirePage('codeforces.listProblems', target)
    case 'cf-problem':
      return requirePage('codeforces.readProblem', target)
    case 'cf-contest':
      return requirePage('codeforces.getContest', target)
    default:
      throw new Error(
        'Usage: tsuki-agent <serve|pages|active|describe|snapshot|query|text|attributes|bounds|cf-problems|cf-problem|cf-contest>',
      )
  }
}

function requirePage(capability, target, payload = {}) {
  if (!target?.pageId) throw new Error(`${capability} requires a page ID.`)
  return { capability, options: { target, payload } }
}

function readOption(args, name) {
  const index = args.indexOf(name)
  return index >= 0 ? args[index + 1] : undefined
}

function readNumberOption(args, name) {
  const value = readOption(args, name)
  return value ? Number(value) : undefined
}

function readPortOption(args) {
  const value = readOption(args, '--port')
  if (value === undefined) return 7072
  const port = Number(value)
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error('--port must be an integer between 1 and 65535.')
  }
  return port
}
