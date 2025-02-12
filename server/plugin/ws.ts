import { Subscriber } from '@guanghechen/viewmodel'
import type { Plugin } from 'vite'
import { SERVER_HOST, SERVER_PORT } from '../../env'
import type { IResponsePayloadFileChanged, IResponsePayloadFileSwitch } from '../../shared/types'
import { ServerCustomEventType } from '../../shared/types'
import state from '../state'
import { sleep } from '../util/misc'
import { openBrowser } from '../util/open'

const plugin = (): Plugin => {
  return {
    name: '@guanghechen/ws',
    configureServer(server) {
      state.fileChanged$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              const payload: IResponsePayloadFileChanged = { filepath }
              server.ws.send({
                type: 'custom',
                event: ServerCustomEventType.FILE_CHANGED,
                data: payload,
              })
            }
          },
        }),
      )
      state.fileSwitch$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              void (async () => {
                try {
                  const payload: IResponsePayloadFileSwitch = { filepath }
                  server.ws.send({
                    type: 'custom',
                    event: ServerCustomEventType.FILE_SWITCHED,
                    data: payload,
                  })

                  const url: string = `http://${SERVER_HOST}:${SERVER_PORT}`
                  await openBrowser(url, true)

                  await sleep(500)
                  server.ws.send({
                    type: 'custom',
                    event: ServerCustomEventType.FILE_SWITCHED,
                    data: payload,
                  })
                } catch (error) {
                  state.reporter.error('Failed to notify the FILE_SWITCHED event. error:', error)
                }
              })()
            }
          },
        }),
      )
    },
  }
}

export default plugin
