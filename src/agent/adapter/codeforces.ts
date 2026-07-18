import type { IAgentPageAdapter } from '@/agent/contract'

export const codeforcesAgentAdapter: IAgentPageAdapter = {
  website: 'codeforces',
  capabilities: ['codeforces.listProblems', 'codeforces.readProblem', 'codeforces.getContest'],
  execute(capability, _payload, signal) {
    if (signal.aborted) throw Object.assign(new Error('Request cancelled.'), { code: 'TIMEOUT' })

    switch (capability) {
      case 'codeforces.listProblems':
        return listProblems()
      case 'codeforces.readProblem':
        return readProblem()
      case 'codeforces.getContest':
        return getContest()
      default:
        throw Object.assign(new Error(`Unsupported Codeforces capability: ${capability}`), {
          code: 'CAPABILITY_UNAVAILABLE',
        })
    }
  },
}

function listProblems(): {
  readonly problems: ReadonlyArray<{
    readonly index: string
    readonly name: string
    readonly url: string
  }>
} {
  const problems = [...document.querySelectorAll('.problems tr')]
    .map(row => {
      const links = row.querySelectorAll<HTMLAnchorElement>('a')
      const indexLink = links[0]
      const nameLink = links[1]
      if (!indexLink || !nameLink) return null
      return {
        index: normalizeText(indexLink.textContent),
        name: normalizeText(nameLink.textContent),
        url: sanitizeUrl(nameLink.href),
      }
    })
    .filter((value): value is NonNullable<typeof value> => value !== null)
  return { problems }
}

function readProblem(): {
  readonly title: string
  readonly statement: string
  readonly input: string
  readonly output: string
} {
  const statement = document.querySelector('.problem-statement')
  if (!statement)
    throw Object.assign(new Error('Problem statement is not present.'), { code: 'PAGE_NOT_FOUND' })
  return {
    title: readText(statement.querySelector('.title'), 500),
    statement: readText(statement, 50_000),
    input: readText(statement.querySelector('.input-specification'), 15_000),
    output: readText(statement.querySelector('.output-specification'), 15_000),
  }
}

function getContest(): {
  readonly title: string
  readonly phase: string
} {
  return {
    title: readText(document.querySelector('#sidebar .rtable a, .contest-name'), 1_000),
    phase: readText(document.querySelector('.contest-state-phase'), 200),
  }
}

function readText(element: Element | null, limit: number): string {
  return normalizeText(element?.textContent).slice(0, limit)
}

function normalizeText(value: string | null | undefined): string {
  return (value ?? '').replace(/\s+/g, ' ').trim()
}

function sanitizeUrl(value: string): string {
  try {
    const url = new URL(value, window.location.href)
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return ''
    return `${url.origin}${url.pathname}`
  } catch {
    return ''
  }
}
