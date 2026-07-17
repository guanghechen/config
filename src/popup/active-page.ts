import { TsukiContentEventNameEnum } from '@/shared/enum/event'
import type { ITsukiPageStatusResponse } from '@/shared/types/event'

const PAGE_STATUS_TIMEOUT_MS = 1500

export interface IActivePageStatus {
  readonly enabled: boolean
  readonly label: string
  readonly url: string
}

export async function readActivePageStatus(): Promise<IActivePageStatus | null> {
  if (typeof chrome === 'undefined' || !chrome.tabs?.query) return null

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
  if (!tab?.id || !tab.url) return null

  const response = await readContentPageStatus(tab.id)
  if (!response) return null

  return {
    enabled: response.enabled,
    label: resolvePageLabel(tab.url),
    url: tab.url,
  }
}

async function readContentPageStatus(tabId: number): Promise<ITsukiPageStatusResponse | null> {
  const request = chrome.tabs.sendMessage(tabId, {
    event: TsukiContentEventNameEnum.PAGE_STATUS,
  })
  const response = await resolveWithTimeout(request, PAGE_STATUS_TIMEOUT_MS)
  return isPageStatusResponse(response) ? response : null
}

function resolveWithTimeout<T>(request: Promise<T>, timeoutMs: number): Promise<T | null> {
  return new Promise(resolve => {
    const timeoutId = window.setTimeout(() => resolve(null), timeoutMs)
    void request.then(
      value => {
        window.clearTimeout(timeoutId)
        resolve(value)
      },
      () => {
        window.clearTimeout(timeoutId)
        resolve(null)
      },
    )
  })
}

function isPageStatusResponse(value: unknown): value is ITsukiPageStatusResponse {
  if (!value || typeof value !== 'object') return false
  const response = value as Partial<ITsukiPageStatusResponse>
  return response.supported === true && typeof response.enabled === 'boolean'
}

function resolvePageLabel(url: string): string {
  const hostname = new URL(url).hostname
  return hostname.replace(/^www\./, '')
}
