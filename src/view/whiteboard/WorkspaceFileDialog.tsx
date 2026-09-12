import React from 'react'
import { workspaceController } from '@/shared/api/workspace'
import { useGetWorkspaceFiles } from '@/hook/api/workspace/files'
import { relativeWorkspaceFilepath } from '@/common/util/path'
import { isWhiteboardFilename } from '@/shared/whiteboard/files'

export const WorkspaceFileDialog: React.FC<{
  mode: 'reference' | 'save'
  title: string
  directory?: string
  onChoose: (filepath: string) => void | Promise<void>
  onClose: () => void
}> = ({ mode, title, directory, onChoose, onClose }) => {
  const [roots, setRoots] = React.useState<string[]>([])
  const [root, setRoot] = React.useState(directory ?? '')
  const [rootInput, setRootInput] = React.useState(directory ?? '')
  const [query, setQuery] = React.useState('')
  const [filepath, setFilepath] = React.useState('')
  const [filename, setFilename] = React.useState(
    `${title.replace(/[^\p{L}\p{N} _-]/gu, '').slice(0, 80) || 'whiteboard'}.whiteboard`,
  )
  const [busy, setBusy] = React.useState(false)
  const [error, setError] = React.useState('')
  const listing = useGetWorkspaceFiles(mode === 'reference' ? root || null : null, 0)
  React.useEffect(() => {
    let cancelled = false
    void workspaceController
      .list()
      .then(config => {
        if (cancelled) return
        const options = [
          ...new Set([
            ...config.defaultWorkspaceRoots,
            ...config.legacyWorkspaces.map(item => item.path),
          ]),
        ]
        setRoots(options)
        if (!directory && options[0]) {
          setRoot(current => current || options[0])
          setRootInput(current => current || options[0])
        }
      })
      .catch(reason => {
        if (!cancelled) setError(reason instanceof Error ? reason.message : String(reason))
      })
    return () => {
      cancelled = true
    }
  }, [directory])
  const files = listing.files.filter(
    file => file.toLowerCase().endsWith('.md') && file.toLowerCase().includes(query.toLowerCase()),
  )
  return (
    <form
      className="wb-reference wb-file-dialog"
      data-wb-ui
      role="dialog"
      aria-label={mode === 'save' ? 'Save whiteboard as' : 'Reference Markdown'}
      onKeyDown={event => {
        event.stopPropagation()
        if (event.key === 'Escape' && !busy) {
          event.preventDefault()
          onClose()
        }
      }}
      onSubmit={event => {
        event.preventDefault()
        if (busy) return
        if (mode === 'save' && (!rootInput.startsWith('/') || !isWhiteboardFilename(filename))) {
          setError('Choose an absolute directory and a filename ending in .whiteboard')
          return
        }
        const path = mode === 'save' ? `${rootInput.replace(/\/+$/, '')}/${filename}` : filepath
        if (
          !path.startsWith('/') ||
          (mode === 'reference' && !path.toLowerCase().endsWith('.md'))
        ) {
          setError('Choose an absolute path within the allowed workspace')
          return
        }
        setBusy(true)
        setError('')
        void Promise.resolve()
          .then(() => onChoose(path))
          .catch(reason => {
            setError(reason instanceof Error ? reason.message : String(reason))
            setBusy(false)
          })
      }}
    >
      <h2>{mode === 'save' ? 'Save whiteboard as' : 'Reference Markdown'}</h2>
      {roots.length > 0 && (
        <label>
          Workspace
          <select
            aria-label="Workspace"
            value={roots.includes(rootInput) ? rootInput : ''}
            disabled={busy}
            onChange={event => {
              setRootInput(event.target.value)
              setRoot(event.target.value)
            }}
          >
            <option value="">Custom directory</option>
            {roots.map(path => (
              <option key={path} value={path}>
                {path}
              </option>
            ))}
          </select>
        </label>
      )}
      <label>
        Directory
        <input
          aria-label="Directory"
          value={rootInput}
          disabled={busy}
          placeholder="/absolute/workspace"
          onChange={event => setRootInput(event.target.value)}
        />
      </label>
      {mode === 'reference' ? (
        <>
          <button
            type="button"
            disabled={busy || !rootInput.startsWith('/')}
            onClick={() => setRoot(rootInput)}
          >
            Browse directory
          </button>
          <input
            aria-label="Find Markdown file"
            placeholder="Search Markdown files…"
            value={query}
            onChange={event => setQuery(event.target.value)}
          />
          <div className="wb-file-list" role="group" aria-label="Markdown files">
            {listing.loading ? (
              <p>Loading files…</p>
            ) : (
              files.slice(0, 100).map(path => (
                <button
                  key={path}
                  type="button"
                  aria-pressed={filepath === path}
                  onClick={() => setFilepath(path)}
                  title={path}
                >
                  {relativeWorkspaceFilepath(path, listing.root ?? root)}
                </button>
              ))
            )}
            {!listing.loading && !files.length && (
              <p>No matching Markdown files. You can enter a path below.</p>
            )}
            {files.length > 100 && <p>Showing 100 files. Refine the search for more results.</p>}
          </div>
          <label>
            Markdown file path
            <input
              aria-label="Markdown file path"
              value={filepath}
              disabled={busy}
              onChange={event => setFilepath(event.target.value)}
            />
          </label>
        </>
      ) : (
        <label>
          Filename
          <input
            autoFocus
            aria-label="Filename"
            value={filename}
            disabled={busy}
            onChange={event => setFilename(event.target.value)}
          />
        </label>
      )}
      {(error || listing.error) && <p role="alert">{error || listing.error}</p>}
      <footer>
        <button type="button" disabled={busy} onClick={onClose}>
          Cancel
        </button>
        <button className="wb-primary" disabled={busy} type="submit">
          {busy ? 'Saving…' : mode === 'save' ? 'Create file' : 'Add reference'}
        </button>
      </footer>
    </form>
  )
}
