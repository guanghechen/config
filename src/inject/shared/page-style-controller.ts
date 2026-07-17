import { TsukiContentEventNameEnum } from '@/shared/enum/event'
import { readPageEnabled, subscribePageEnabled } from '@/shared/setting/page-enabled'
import type { ITsukiPageStatusResponse } from '@/shared/types/event'

interface IPageStyleControllerOptions {
  readonly setEnabled: (enabled: boolean) => void
}

export function startPageStyleController(options: IPageStyleControllerOptions): () => void {
  let disposed = false
  let enabled: boolean | null = null
  let storageRevision = 0

  let markReady: () => void = () => undefined
  const ready = new Promise<void>(resolve => {
    markReady = resolve
  })

  const updateEnabled = (nextValue: boolean) => {
    if (disposed || nextValue === enabled) return
    enabled = nextValue
    options.setEnabled(nextValue)
  }

  const unsubscribePageEnabled = subscribePageEnabled(window.location.href, nextValue => {
    storageRevision += 1
    updateEnabled(nextValue)
  })

  const initialStorageRevision = storageRevision
  void readPageEnabled(window.location.href)
    .then(value => {
      if (storageRevision === initialStorageRevision) updateEnabled(value)
    })
    .catch(() => {
      if (storageRevision === initialStorageRevision) updateEnabled(true)
    })
    .finally(markReady)

  const handleMessage = (
    message: unknown,
    _sender: chrome.runtime.MessageSender,
    sendResponse: (response: ITsukiPageStatusResponse) => void,
  ): boolean | undefined => {
    if (!isPageStatusRequest(message)) return undefined

    void ready.then(() => {
      sendResponse({ enabled: enabled ?? true, supported: true })
    })
    return true
  }

  chrome.runtime.onMessage.addListener(handleMessage)

  return () => {
    if (disposed) return
    disposed = true
    unsubscribePageEnabled()
    chrome.runtime.onMessage.removeListener(handleMessage)
    options.setEnabled(false)
  }
}

function isPageStatusRequest(message: unknown): boolean {
  if (!message || typeof message !== 'object') return false
  return (message as { event?: unknown }).event === TsukiContentEventNameEnum.PAGE_STATUS
}
