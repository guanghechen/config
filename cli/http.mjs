import fs from 'node:fs/promises'
import path from 'node:path'
import { v4 } from 'uuid'
import dayjs from 'dayjs'
import {
  envParser,
  git,
  httpParser,
  makeHttpRequest,
  isServerSentEvent,
  handleSseResponse,
  writeHttpRequest,
  writeHttpResponse,
  writeErrorOutput,
} from '#shared'

const regexes = {
  splitter: /\n[-]{100}\n/,
  template: /\{\{\s*(\w+(?:\(\))?)\s*\}\}/g,
}

const functionResolvers = {
  uuid: () => v4(),
  uuidv4: () => v4(),
  date: format => (format ? dayjs().format(format) : dayjs().toISOString()),
  timestamp: () => Date.now(),
  timestampSec: () => Math.floor(Date.now() / 1000),
}

function resolveFunction(expr) {
  const trimmed = expr.trim()
  const funcMatch = trimmed.match(/^(\w+)\((.*)\)$/)

  if (!funcMatch) return null

  const [, funcName, argsStr] = funcMatch
  const resolver = functionResolvers[funcName]

  if (!resolver) return null

  const args = argsStr.trim()
  if (!args) return resolver()

  const cleanArgs = args.replace(/^['"]|['"]$/g, '')
  return resolver(cleanArgs)
}

/**
 * @param {string} filepath
 * @returns {Promise<Record<string, unknown>>}
 */
async function loadEnv(filepath) {
  let env = { ...process.env }

  const to = path.dirname(filepath)
  const gitRepoRootDir = git.resolveGitRepoRootDir(to)
  const from = gitRepoRootDir || to

  await envParser.loads(from, to, env)
  return env
}

/**
 * @param {string} filepath
 * @returns {Promise<void>}
 */
async function run(filepath) {
  const requestPath = filepath + '_request'
  const responsePath = filepath + '_response'
  const httpContent = await fs.readFile(filepath, 'utf8')
  const parts = httpContent.split(regexes.splitter)

  let httpText = httpContent
  let env = await loadEnv(filepath)

  if (parts.length === 1) {
    httpText = parts[0]
  } else if (parts.length === 2) {
    const [envText, requestText] = parts
    httpText = requestText

    if (envText.trim()) {
      const parsed = envParser.parse(envText)
      env = { ...env, ...parsed }
    }
  }

  const processedHttpText = httpText.trim().replace(regexes.template, (match, expr) => {
    const resolved = resolveFunction(expr)
    if (resolved !== null) return resolved

    const key = expr.trim()
    return env[key] || match
  })
  const parsedRequest = httpParser.parse(processedHttpText)

  await writeHttpRequest(parsedRequest, requestPath)
  console.log(`Request saved to: ${requestPath}`)

  console.log('Making request to:', parsedRequest.url)
  console.log('Method:', parsedRequest.method)

  try {
    const response = await makeHttpRequest(parsedRequest)

    // Check if this is an SSE response
    if (isServerSentEvent(response)) {
      await handleSseResponse(response, responsePath, parsedRequest)
      console.log(`Status: ${response.status} ${response.statusText}`)
      return
    }

    // Handle regular (non-SSE) responses
    const responseText = await response.text()
    await writeHttpResponse(response, responseText, parsedRequest, responsePath)

    console.log(`Response saved to: ${responsePath}`)
    console.log(`Status: ${response.status} ${response.statusText}`)
  } catch (error) {
    console.error('Request failed:', error.message)
    await writeErrorOutput(error, responsePath)
    console.log(`Error saved to: ${responsePath}`)
  }
}

const httpFilepath = process.argv[2]
if (!httpFilepath) {
  console.error('Usage: node http.mjs <http-file-path>')
  process.exit(1)
}

const resolvedPath = path.isAbsolute(httpFilepath)
  ? httpFilepath
  : path.resolve(process.cwd(), httpFilepath)

await run(resolvedPath)
