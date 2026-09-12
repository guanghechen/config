import React from 'react'
import { parseDocument } from '@/shared/whiteboard/document'
import { orderedDocument } from '@/shared/whiteboard/stacking'
import type { IWhiteboardDocument } from '@/shared/whiteboard/model'
import type { BoardStore } from '../store'
import type { BoardTypography } from '../rendering/typography'
import { useBoardHost } from '../HostContext'
import type { IWhiteboardFile } from '../contracts'

export function useDocumentFile({
  filepath,
  store,
  typography,
  recovered,
  initialRevision,
  isBusy,
  onMessage,
  onStatus,
  fit,
  getGeneration,
  nextGeneration,
}: {
  filepath?: string
  store: BoardStore
  typography: BoardTypography
  recovered?: boolean
  initialRevision?: string
  isBusy: () => boolean
  onMessage: (message: string) => void
  onStatus: (status: string) => void
  fit: () => void
  getGeneration: () => number
  nextGeneration: () => number
}) {
  const { files, drafts, openFile } = useBoardHost()
  // Saving a file owns its request even if the document is replaced by an import.
  const lifetime = React.useRef(0)
  React.useEffect(
    () => () => {
      lifetime.current++
    },
    [],
  )
  const loadFile = React.useCallback(
    async (
      path: string,
      expected?: string,
      signal?: AbortSignal,
    ): Promise<IWhiteboardFile | null> => {
      if (!files) throw new Error('File access is unavailable for this board')
      const data = await files.load(path, expected, signal)
      if (!data && expected === undefined) throw new Error('The file service returned no document')
      return data
    },
    [files],
  )
  const [loading, setLoading] = React.useState(!!filepath && !!files)
  const [saving, setSaving] = React.useState(false)
  const [sourceUpdate, setSourceUpdate] = React.useState<
    { revision: string; title: string; count: number } | { error: string } | null
  >(null)
  const revision = React.useRef(initialRevision)
  const canonicalFilepath = React.useRef(filepath)
  const fileSavedDocument = React.useRef<IWhiteboardDocument | null>(null)
  const createdFileDocument = React.useRef<IWhiteboardDocument | null>(null)
  React.useEffect(() => {
    if (!filepath || !files) return
    const controller = new AbortController()
    const initialDocument = store.getDocument()
    void loadFile(filepath, undefined, controller.signal)
      .then(data => {
        if (!data || controller.signal.aborted) return
        const document = typography.normalize(orderedDocument(parseDocument(data.content)))
        canonicalFilepath.current = data.filepath
        fileSavedDocument.current = document
        if (recovered) {
          if (JSON.stringify(store.getDocument()) === JSON.stringify(document)) {
            fileSavedDocument.current = store.getDocument()
            revision.current = data.revision
          } else if (revision.current !== data.revision) {
            setSourceUpdate({
              revision: data.revision,
              title: document.title,
              count: document.elements.length,
            })
          } else {
            onMessage(
              'Recovered local draft. Saving checks the file version from when the draft was created.',
            )
          }
        } else {
          revision.current = data.revision
          if (store.getDocument() === initialDocument) store.replace(document)
          else
            setSourceUpdate({
              revision: data.revision,
              title: document.title,
              count: document.elements.length,
            })
        }
        onStatus(drafts ? 'File loaded · local draft enabled' : 'File loaded')
      })
      .catch((error: unknown) => {
        if (!controller.signal.aborted) {
          onMessage(error instanceof Error ? error.message : String(error))
        }
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false)
      })
    return () => controller.abort()
  }, [filepath, files, drafts, loadFile, recovered, store, typography, onMessage, onStatus])

  React.useEffect(() => {
    const initialDocument = store.getDocument()
    let saved = store.getDocument()
    let pending: ReturnType<typeof setTimeout> | undefined
    let failed = false
    const persist = (): void => {
      if (!drafts) return
      clearTimeout(pending)
      try {
        drafts.write(
          filepath,
          JSON.stringify({ document: store.getDocument(), revision: revision.current }),
        )
        saved = store.getDocument()
        failed = false
        onStatus('Draft saved locally')
      } catch (error) {
        failed = true
        onMessage(`Draft not saved: ${error instanceof Error ? error.message : String(error)}`)
      }
    }
    const unsubscribe = store.subscribe(() => {
      if (!drafts) return
      if (store.getDocument() === saved) return
      clearTimeout(pending)
      onStatus('Saving local draft…')
      pending = setTimeout(persist, 500)
    })
    const unload = (event: BeforeUnloadEvent): void => {
      const current = store.getDocument()
      if (drafts && current !== saved) persist()
      if (
        (drafts ? failed : current !== initialDocument) &&
        current !== fileSavedDocument.current &&
        current !== createdFileDocument.current
      )
        event.preventDefault()
    }
    window.addEventListener('beforeunload', unload)
    return () => {
      unsubscribe()
      window.removeEventListener('beforeunload', unload)
      clearTimeout(pending)
      if (store.getDocument() !== saved) persist()
    }
  }, [store, drafts, filepath, onMessage, onStatus])

  React.useEffect(() => {
    if (!filepath || !files || loading || saving) return
    let controller: AbortController | undefined
    const refresh = (force = false): void => {
      if (!revision.current) return
      if (controller && !force) return
      controller?.abort()
      const request = new AbortController()
      controller = request
      const expectedRevision = revision.current
      void loadFile(canonicalFilepath.current ?? filepath, expectedRevision, request.signal)
        .then(data => {
          if (request.signal.aborted || revision.current !== expectedRevision) return
          if (!data) {
            setSourceUpdate(current => (current && 'error' in current ? null : current))
            return
          }
          const document = typography.normalize(orderedDocument(parseDocument(data.content)))
          canonicalFilepath.current = data.filepath
          const current = store.getDocument()
          const busy = isBusy()
          if (
            !busy &&
            current === fileSavedDocument.current &&
            store.getSnapshot().document === current
          ) {
            revision.current = data.revision
            fileSavedDocument.current = document
            store.replace(document)
            setSourceUpdate(null)
            onStatus('Updated from source file')
          } else {
            setSourceUpdate(previous =>
              previous && 'revision' in previous && previous.revision === data.revision
                ? previous
                : {
                    revision: data.revision,
                    title: document.title,
                    count: document.elements.length,
                  },
            )
          }
        })
        .catch((error: unknown) => {
          if (!request.signal.aborted && revision.current === expectedRevision)
            setSourceUpdate({
              error: `Unable to refresh source: ${error instanceof Error ? error.message : String(error)}`,
            })
        })
        .finally(() => {
          if (controller === request) controller = undefined
        })
    }
    const focus = (): void => refresh(true)
    const changed = (changedPath: string): void => {
      if (changedPath === filepath || changedPath === canonicalFilepath.current) refresh(true)
    }
    const timer = setInterval(refresh, 2500)
    window.addEventListener('focus', focus)
    let unsubscribe: (() => void) | undefined
    try {
      unsubscribe = files?.subscribe?.(changed)
    } catch {
      // File notifications are optional; polling and focus refresh remain available.
    }
    refresh()
    return () => {
      clearInterval(timer)
      controller?.abort()
      window.removeEventListener('focus', focus)
      unsubscribe?.()
    }
  }, [filepath, files, loadFile, loading, saving, store, isBusy, typography, onStatus])
  const saveFile = async (): Promise<void> => {
    if (!filepath || !files || !revision.current || saving) return
    const document = store.getDocument()
    const generation = lifetime.current
    setSaving(true)
    try {
      const savedRevision = await files.save(
        filepath,
        JSON.stringify(document, null, 2),
        revision.current,
      )
      if (generation !== lifetime.current) return
      revision.current = savedRevision
      fileSavedDocument.current = document
      setSourceUpdate(null)
      drafts?.write(
        filepath,
        JSON.stringify({ document: store.getDocument(), revision: revision.current }),
      )
      onStatus(
        store.getDocument() === document
          ? 'Saved to file'
          : 'File saved · newer local changes remain',
      )
      onMessage('')
    } catch (error) {
      if (generation === lifetime.current)
        onMessage(error instanceof Error ? error.message : String(error))
    } finally {
      if (generation === lifetime.current) setSaving(false)
    }
  }

  const reloadFile = async (): Promise<void> => {
    if (
      !filepath ||
      !files ||
      loading ||
      saving ||
      !window.confirm('Reload from disk and discard local changes? Export first to keep a copy.')
    )
      return
    const generation = nextGeneration()
    const owner = lifetime.current
    setLoading(true)
    try {
      const data = await loadFile(filepath)
      if (!data || owner !== lifetime.current || generation !== getGeneration()) return
      const document = typography.normalize(orderedDocument(parseDocument(data.content)))
      revision.current = data.revision
      canonicalFilepath.current = data.filepath
      fileSavedDocument.current = document
      store.replace(document)
      setSourceUpdate(null)
      onMessage('')
      fit()
    } catch (error) {
      if (owner === lifetime.current && generation === getGeneration())
        onMessage(error instanceof Error ? error.message : String(error))
    } finally {
      if (owner === lifetime.current) setLoading(false)
    }
  }

  const saveAsFile = async (target: string): Promise<void> => {
    if (!files || !openFile) throw new Error('Creating files is unavailable for this board')
    const generation = getGeneration()
    const owner = lifetime.current

    if (drafts?.read(target))
      throw new Error('A local draft already exists at that path. Choose another filename.')
    const slash = target.lastIndexOf('/')
    const current = store.getDocument()
    const created = await files!.create(
      target.slice(0, slash) || '/',
      target.slice(slash + 1),
      JSON.stringify(current, null, 2),
    )
    if (owner !== lifetime.current) return
    if (generation !== getGeneration())
      throw new Error(
        `Created ${created.filepath}, but the board changed. Open the file separately to review it.`,
      )
    if (drafts?.read(created.filepath))
      throw new Error(
        `Created ${created.filepath}; an existing local draft was preserved. Open the file separately to review it.`,
      )
    createdFileDocument.current = current
    if (store.getDocument() !== current) {
      try {
        if (!drafts) throw new Error('Draft storage is unavailable')
        drafts.write(
          created.filepath,
          JSON.stringify({ document: store.getDocument(), revision: created.revision }),
        )
      } catch {
        throw new Error(
          `Created ${created.filepath}, but newer changes could not be saved as a local draft. Export them before leaving this board.`,
        )
      }
    }
    openFile?.(created.filepath)
  }
  return {
    loading,
    saving,
    sourceUpdate,
    canSave: !!revision.current,
    saveFile,
    reloadFile,
    saveAsFile,
  }
}
