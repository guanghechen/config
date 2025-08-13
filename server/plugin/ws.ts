import { Subscriber } from '@guanghechen/viewmodel'
import type { Plugin } from 'vite'
import { SERVER_HOST, SERVER_PORT } from '../../env'
import type { IResponsePayloadFileSwitch } from '../../shared/types'
import { ServerCustomEventType } from '../../shared/types'
import state from '../state'
import { sleep } from '../util/misc'
import { openBrowser } from '../util/open'
import { toSearch } from '../util/url'

const plugin = (): Plugin => {
  return {
    name: '@guanghechen/ws',
    configureServer(server) {
      state.fileChanged$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              const { workspace, relativePath } = state.sharpFilepath(filepath)
              const payload: IResponsePayloadFileSwitch = { workspace, filepath: relativePath }
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
              const { workspace, relativePath } = state.sharpFilepath(filepath)
              const payload: IResponsePayloadFileSwitch = { workspace, filepath: relativePath }
              server.ws.send({
                type: 'custom',
                event: ServerCustomEventType.FILE_SWITCHED,
                data: payload,
              })

              const force: boolean = state.fileSwitchArgForce$.getSnapshot()
              if (force) {
                void forceOpen()

                async function forceOpen(): Promise<void> {
                  const search: string = workspace
                    ? toSearch({ filepath: relativePath })
                    : toSearch({ filepath })
                  const url: string = workspace
                    ? `http://${SERVER_HOST}:${SERVER_PORT}/ws/${workspace}/${search}`
                    : `http://${SERVER_HOST}:${SERVER_PORT}/file${search}`

                  try {
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
                }
              }
            }
          },
        }),
      )
    },
  }
}

export default plugin
