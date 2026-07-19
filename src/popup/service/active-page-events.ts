export function subscribeActivePageChanges(listener: () => void): () => void {
  if (typeof chrome === 'undefined' || !chrome.tabs || !chrome.windows) return () => undefined

  const handleActivated = () => listener()
  const handleUpdated = (
    _tabId: number,
    changeInfo: { readonly status?: string; readonly url?: string },
    tab: chrome.tabs.Tab,
  ) => {
    if (!tab.active || (changeInfo.status === undefined && changeInfo.url === undefined)) return
    listener()
  }
  const handleFocusChanged = (windowId: number) => {
    if (windowId !== chrome.windows.WINDOW_ID_NONE) listener()
  }

  chrome.tabs.onActivated.addListener(handleActivated)
  chrome.tabs.onUpdated.addListener(handleUpdated)
  chrome.windows.onFocusChanged.addListener(handleFocusChanged)
  return () => {
    chrome.tabs.onActivated.removeListener(handleActivated)
    chrome.tabs.onUpdated.removeListener(handleUpdated)
    chrome.windows.onFocusChanged.removeListener(handleFocusChanged)
  }
}
