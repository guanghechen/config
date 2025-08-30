import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useAuthViewModel } from '@/context/auth'

interface IProps {
  readonly isOpen: boolean
  readonly onClose: () => void
}

export const LoginModal: React.FC<IProps> = ({ isOpen, onClose }) => {
  const authViewModel = useAuthViewModel()
  const loading = useStateValue(authViewModel.loading$)
  const error = useStateValue(authViewModel.error$)
  const isAuthenticated = useStateValue(authViewModel.isAuthenticated$)

  const [username, setUsername] = React.useState('')
  const [password, setPassword] = React.useState('')
  const usernameRef = React.useRef<HTMLInputElement>(null)
  const passwordRef = React.useRef<HTMLInputElement>(null)

  // Check for autofilled values
  const checkAutofill = React.useCallback(() => {
    if (usernameRef.current && passwordRef.current) {
      const usernameValue = usernameRef.current.value
      const passwordValue = passwordRef.current.value

      if (usernameValue && usernameValue !== username) {
        setUsername(usernameValue)
      }
      if (passwordValue && passwordValue !== password) {
        setPassword(passwordValue)
      }
    }
  }, [username, password])

  // Detect autofill using multiple strategies
  React.useEffect(() => {
    if (!isOpen) return

    // Strategy 1: Check immediately and after short delays
    const timeouts = [0, 100, 500, 1000].map(delay => setTimeout(checkAutofill, delay))

    // Strategy 2: Check on animation frame (for browsers that autofill on next frame)
    const rafId = requestAnimationFrame(checkAutofill)

    // Strategy 3: Poll periodically for the first few seconds
    const pollInterval = setInterval(checkAutofill, 100)
    const stopPolling = setTimeout(() => clearInterval(pollInterval), 3000)

    return () => {
      timeouts.forEach(clearTimeout)
      cancelAnimationFrame(rafId)
      clearInterval(pollInterval)
      clearTimeout(stopPolling)
    }
  }, [isOpen, checkAutofill])

  React.useEffect(() => {
    if (isAuthenticated) {
      onClose()
      setUsername('')
      setPassword('')
    }
  }, [isAuthenticated, onClose])

  React.useEffect(() => {
    if (error) {
      // Clear error after 5 seconds
      const timer = setTimeout(() => {
        authViewModel.clearError()
      }, 5000)
      return () => clearTimeout(timer)
    }
  }, [error, authViewModel])

  const handleSubmit = React.useCallback(
    (e: React.FormEvent) => {
      e.preventDefault()
      if (!username.trim() || !password.trim()) return

      void authViewModel.login({ username: username.trim(), password })
    },
    [username, password, authViewModel],
  )

  const handleKeyDown = React.useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    },
    [onClose],
  )

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
      onKeyDown={handleKeyDown}
      tabIndex={-1}
    >
      <div className="w-full max-w-md rounded-lg bg-white p-6 shadow-xl dark:bg-gray-800">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-white">Sign In</h2>
          <button
            type="button"
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            aria-label="Close modal"
          >
            <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label
              htmlFor="username"
              className="block text-sm font-medium text-gray-700 dark:text-gray-300"
            >
              Username
            </label>
            <input
              ref={usernameRef}
              id="username"
              type="text"
              value={username}
              onChange={e => setUsername(e.target.value)}
              onAnimationStart={checkAutofill}
              onInput={checkAutofill}
              disabled={loading}
              className={cn(
                'mt-1 block w-full rounded-md border border-gray-300 px-3 py-2',
                'text-gray-900 placeholder-gray-500',
                'focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500',
                'dark:border-gray-600 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400',
                'disabled:cursor-not-allowed disabled:opacity-50',
              )}
              placeholder="Enter your username"
              autoComplete="username"
              autoFocus={true}
            />
          </div>

          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium text-gray-700 dark:text-gray-300"
            >
              Password
            </label>
            <input
              ref={passwordRef}
              id="password"
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              onAnimationStart={checkAutofill}
              onInput={checkAutofill}
              disabled={loading}
              className={cn(
                'mt-1 block w-full rounded-md border border-gray-300 px-3 py-2',
                'text-gray-900 placeholder-gray-500',
                'focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500',
                'dark:border-gray-600 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400',
                'disabled:cursor-not-allowed disabled:opacity-50',
              )}
              placeholder="Enter your password"
              autoComplete="current-password"
            />
          </div>

          {error && (
            <div className="rounded-md bg-red-50 p-3 dark:bg-red-900/20">
              <div className="text-sm text-red-800 dark:text-red-200">{error}</div>
            </div>
          )}

          <div className="flex justify-end space-x-3">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className={cn(
                'rounded-md border border-gray-300 px-4 py-2 text-sm font-medium',
                'text-gray-700 hover:bg-gray-50',
                'dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700',
                'disabled:cursor-not-allowed disabled:opacity-50',
              )}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading || !username.trim() || !password.trim()}
              className={cn(
                'rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white',
                'hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
                'disabled:cursor-not-allowed disabled:opacity-50',
                'dark:focus:ring-offset-gray-800',
              )}
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
