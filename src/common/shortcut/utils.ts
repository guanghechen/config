import type { IKeyBinding, Platform } from './types'

/**
 * Creates platform-aware keybindings that use appropriate modifier keys
 * @param key The key to bind
 * @param callback The callback function
 * @param options Additional options
 */
export function createPlatformKeybinding(
  key: string,
  callback: (event: KeyboardEvent) => void,
  options: {
    useCtrl?: boolean
    useAlt?: boolean
    useShift?: boolean
    priority?: number
    platform?: Platform
  } = {},
): IKeyBinding {
  const { useCtrl = false, useAlt = false, useShift = false, priority, platform = 'all' } = options

  // On macOS, use metaKey (Cmd) instead of ctrlKey for primary shortcuts
  if (platform === 'osx' || (platform === 'all' && navigator.userAgent.includes('Mac'))) {
    return {
      key,
      metaKey: useCtrl,
      altKey: useAlt,
      shiftKey: useShift,
      callback,
      priority,
      platform,
    }
  }

  // On Windows/Linux, use ctrlKey
  return {
    key,
    ctrlKey: useCtrl,
    altKey: useAlt,
    shiftKey: useShift,
    callback,
    priority,
    platform,
  }
}

/**
 * Creates multiple keybindings for cross-platform compatibility
 * @param key The key to bind
 * @param callback The callback function
 * @param options Additional options
 */
export function createCrossPlatformKeybinding(
  key: string,
  callback: (event: KeyboardEvent) => void,
  options: {
    useCtrl?: boolean
    useAlt?: boolean
    useShift?: boolean
    priority?: number
  } = {},
): IKeyBinding[] {
  const { useCtrl = false, useAlt = false, useShift = false, priority } = options

  return [
    // macOS binding (Cmd key)
    {
      key,
      metaKey: useCtrl,
      altKey: useAlt,
      shiftKey: useShift,
      callback,
      priority,
      platform: 'osx' as Platform,
    },
    // Windows/Linux binding (Ctrl key)
    {
      key,
      ctrlKey: useCtrl,
      altKey: useAlt,
      shiftKey: useShift,
      callback,
      priority,
      platform: 'win' as Platform,
    },
    {
      key,
      ctrlKey: useCtrl,
      altKey: useAlt,
      shiftKey: useShift,
      callback,
      priority,
      platform: 'nix' as Platform,
    },
  ]
}
