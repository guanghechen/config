const GITMOJI_REPLACEMENTS: Readonly<Record<string, string>> = Object.freeze({
  bento: '🍱',
  building_construction: '🏗️',
  fire: '🔥',
  memo: '📝',
  recycle: '♻️',
  see_no_evil: '🙈',
  sparkles: '✨',
  tada: '🎉',
  white_check_mark: '✅',
  wrench: '🔧',
})

export function formatCommitSubject(subject: string): string {
  return subject.replace(/:([a-z0-9_+-]+):/g, (alias, name: string) => {
    return GITMOJI_REPLACEMENTS[name] ?? alias
  })
}
