import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useNavigate } from 'react-router-dom'
import { ChevronRightIcon, ViewStreamIcon } from '@/common/component/icon/material'
import cn from '@/common/util/clsx'
import { normalizeAbsoluteFilepath } from '@/common/util/path'
import { workspaceController } from '@/shared/api'
import { createWorkspaceUrl, useWorkspaceViewmodel } from '../context'

const rootName = (root: string): string => root.split('/').filter(Boolean).at(-1) || root

export const WorkspaceSelector: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const currentWorkspaceRoot = useStateValue(viewmodel.workspaceRoot$)
  const workspaceRoots = useStateValue(viewmodel.workspaceRoots$)
  const navigate = useNavigate()

  const [isOpen, setIsOpen] = React.useState(false)
  const [rootInput, setRootInput] = React.useState('')
  const [rootError, setRootError] = React.useState<string | null>(null)
  const [validating, setValidating] = React.useState(false)
  const validationGenerationRef = React.useRef(0)

  React.useEffect(() => {
    return () => {
      validationGenerationRef.current += 1
    }
  }, [])

  const handleWorkspaceSelect = React.useCallback(
    (root: string): void => {
      validationGenerationRef.current += 1
      setIsOpen(false)
      setRootError(null)
      void navigate(createWorkspaceUrl(root))
    },
    [navigate],
  )

  const handleWorkspaceRemove = React.useCallback(
    (event: React.MouseEvent, root: string): void => {
      event.preventDefault()
      event.stopPropagation()
      validationGenerationRef.current += 1
      const nextRoots = workspaceRoots.filter(item => item !== root)
      viewmodel.removeWorkspaceRoot(root)
      if (currentWorkspaceRoot === root) {
        const nextRoot = nextRoots[0] ?? null
        viewmodel.workspaceRoot$.next(nextRoot)
        viewmodel.filepath$.next(null)
        void navigate(createWorkspaceUrl(nextRoot))
      }
    },
    [currentWorkspaceRoot, navigate, viewmodel, workspaceRoots],
  )

  const handleWorkspaceAdd = React.useCallback(async (): Promise<void> => {
    const root = normalizeAbsoluteFilepath(rootInput.trim())
    if (!root) {
      setRootError('Enter an absolute path.')
      return
    }

    const generation = validationGenerationRef.current + 1
    validationGenerationRef.current = generation
    setValidating(true)
    setRootError(null)
    try {
      const result = await workspaceController.files(root)
      if (validationGenerationRef.current !== generation) return
      viewmodel.addWorkspaceRoot(result.root)
      setRootInput('')
      setIsOpen(false)
      void navigate(createWorkspaceUrl(result.root))
    } catch (error) {
      if (validationGenerationRef.current !== generation) return
      setRootError(error instanceof Error ? error.message : String(error))
    } finally {
      if (validationGenerationRef.current === generation) setValidating(false)
    }
  }, [navigate, rootInput, viewmodel])

  const handleToggle = React.useCallback((event: React.MouseEvent): void => {
    event.preventDefault()
    event.stopPropagation()
    setIsOpen(open => {
      if (open) validationGenerationRef.current += 1
      return !open
    })
    setRootError(null)
    setValidating(false)
  }, [])

  const handleClose = React.useCallback((): void => {
    validationGenerationRef.current += 1
    setValidating(false)
    setIsOpen(false)
  }, [])

  return (
    <div className="relative min-w-0 shrink-0 max-w-40">
      <button
        type="button"
        onClick={handleToggle}
        className={cn(
          'flex h-8 w-full items-center gap-2 rounded-lg px-2',
          'transition-colors duration-150 ease-in-out focus:outline-none',
          'text-gray-600 hover:bg-gray-100 hover:text-gray-800',
          'dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-gray-100',
        )}
        aria-label="Select workspace"
        aria-expanded={isOpen}
        title={currentWorkspaceRoot || 'Select workspace'}
      >
        <div className="flex min-w-0 flex-1 items-center gap-2">
          <ViewStreamIcon className="h-4 w-4 shrink-0" />
          <span className="truncate text-sm text-gray-700 dark:text-gray-200">
            {currentWorkspaceRoot ? rootName(currentWorkspaceRoot) : 'No workspace'}
          </span>
        </div>
        <ChevronRightIcon className="h-3 w-3 shrink-0 rotate-90" />
      </button>

      {isOpen && (
        <React.Fragment>
          <div className="absolute left-0 top-full z-50 mt-2 w-96 max-w-[calc(100vw-5rem)] overflow-hidden rounded-lg border border-gray-200 bg-white shadow-lg dark:border-gray-600 dark:bg-gray-800">
            <div className="max-h-[min(24rem,60vh)] overflow-y-auto py-1">
              {workspaceRoots.length === 0 ? (
                <div className="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
                  No saved workspace roots
                </div>
              ) : (
                workspaceRoots.map(root => (
                  <div
                    key={root}
                    className={cn(
                      'group flex items-center transition-colors hover:bg-gray-100 dark:hover:bg-gray-700',
                      root === currentWorkspaceRoot &&
                        'bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-300',
                    )}
                  >
                    <button
                      type="button"
                      onClick={() => handleWorkspaceSelect(root)}
                      className="flex min-w-0 flex-1 items-start gap-3 px-4 py-3 text-left text-sm"
                      title={root}
                    >
                      <ViewStreamIcon className="mt-0.5 h-4 w-4 shrink-0" />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-medium">{rootName(root)}</span>
                        <span className="mt-1 block break-all text-left font-mono text-xs font-normal leading-relaxed text-gray-500 dark:text-gray-400">
                          {root}
                        </span>
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={event => handleWorkspaceRemove(event, root)}
                      className="mr-2 rounded px-2 py-1 text-gray-400 opacity-0 transition hover:bg-gray-200 hover:text-red-600 focus:opacity-100 group-hover:opacity-100 dark:hover:bg-gray-600 dark:hover:text-red-300"
                      aria-label={`Remove ${root}`}
                      title="Remove saved root"
                    >
                      ×
                    </button>
                  </div>
                ))
              )}
            </div>
            <div className="border-t border-gray-200 p-3 dark:border-gray-700">
              <form
                onSubmit={event => {
                  event.preventDefault()
                  void handleWorkspaceAdd()
                }}
              >
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={rootInput}
                    onChange={event => setRootInput(event.target.value)}
                    placeholder="/absolute/path/to/workspace"
                    aria-label="Workspace root"
                    className="min-w-0 flex-1 rounded-md border border-gray-300 bg-white px-2.5 py-2 font-mono text-xs text-gray-800 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-900 dark:text-gray-100"
                  />
                  <button
                    type="submit"
                    disabled={validating}
                    className="rounded-md bg-blue-600 px-3 py-2 text-xs font-medium text-white transition hover:bg-blue-700 disabled:cursor-wait disabled:opacity-60"
                  >
                    {validating ? 'Checking…' : 'Add'}
                  </button>
                </div>
                {rootError && (
                  <div className="mt-2 text-xs text-red-600 dark:text-red-300">{rootError}</div>
                )}
              </form>
            </div>
          </div>
          <div className="fixed inset-0 z-40" onClick={handleClose} />
        </React.Fragment>
      )}
    </div>
  )
}

WorkspaceSelector.displayName = 'WorkspaceViewWorkspaceSelector'
