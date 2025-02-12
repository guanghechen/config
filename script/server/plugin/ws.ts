import { Subscriber } from '@guanghechen/viewmodel'
import type { Plugin } from 'vite'
import state from '../state'

const plugin = (): Plugin => {
  return {
    name: '@guanghechen/ws',
    configureServer(server) {
      state.fileChanged$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              server.ws.send({
                type: 'custom',
                event: 'guanghechen/file-changed',
                data: { filepath },
              })
            }
          },
        }),
      )
      state.fileSwitch$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              server.ws.send({
                type: 'custom',
                event: 'guanghechen/file-switch',
                data: { filepath },
              })
            }
          },
        }),
      )
    },
  }
}

export default plugin
