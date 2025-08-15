import type { ITsukiRequestData } from '@/shared/types/event'

window.addEventListener('message', event => {
  if (event.source === window && event.data && event.data.action === '@@tsuki-event@@') {
    const payload = event.data['tsuki']
    const data: ITsukiRequestData = {
      event: payload.event,
      payload: payload.payload,
    }
    void chrome.runtime.sendMessage({ data })
  }
})
