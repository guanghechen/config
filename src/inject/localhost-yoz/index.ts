import type { TsukiEventNameEnum } from '@/shared/enum/event'
import type { ITsukiRequestData } from '@/shared/types/event'

window.addEventListener('message', event => {
  if (event.source === window && event.data && event.data.action === '@@tsuki-event@@') {
    const payload = event.data['tsuki']
    const name: string = '@tsuki/' + payload.event.replace(/^@tsuki\//, '')
    const data: ITsukiRequestData = {
      event: name as TsukiEventNameEnum,
      payload: payload.payload,
    }
    void chrome.runtime.sendMessage({ data })
  }
})
