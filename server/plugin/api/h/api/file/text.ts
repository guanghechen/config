import state from '../../../../../state.ts'
import parseMarkdown from '../../../../../util/parseMarkdown.ts'
import { readVersionedText } from '../../../../../util/versioned-text.ts'
import type { IApiHandle } from '../../../types.ts'

export const fetchFileText: IApiHandle = async ({ req, searchParams }) => {
  if (req.method !== 'GET') return { code: 405, data: { error: 'GET required', data: null } }
  const filepath = state.access.resolve(searchParams.get('filepath'), 'file')
  if (!/\.(md|whiteboard)$/i.test(filepath)) {
    return { code: 400, data: { error: 'Expected a Markdown or whiteboard file', data: null } }
  }
  const snapshot = await readVersionedText(filepath)
  state.watch(filepath)
  if (snapshot.revision === searchParams.get('revision')) {
    return { code: 200, data: { data: { filepath, revision: snapshot.revision, unchanged: true } } }
  }
  const markdown = filepath.toLowerCase().endsWith('.md')
    ? await parseMarkdown(filepath, snapshot.content)
    : undefined
  return { code: 200, data: { data: { filepath, ...snapshot, markdown } } }
}
