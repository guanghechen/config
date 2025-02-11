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
              server.ws.send('guanghechen', {
                type: 'file-changed',
                filepath,
              })
            }
          },
        }),
      )
    },
  }
}

export default plugin
