import { Subscriber } from '@guanghechen/viewmodel'
import type { Plugin } from 'vite'
import type { IResponsePayloadFileChanged, IResponsePayloadFileSwitch } from '../../shared/types'
import { ServerCustomEventType } from '../../shared/types'
import state from '../state'

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
              const payload: IResponsePayloadFileSwitch = { filepath }
              server.ws.send({
                type: 'custom',
                event: ServerCustomEventType.FILE_SWITCHED,
                data: payload,
              })
            }
          },
        }),
      )
    },
  }
}

export default plugin
