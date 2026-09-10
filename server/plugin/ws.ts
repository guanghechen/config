import { Subscriber } from '@guanghechen/subscriber'
import type { IncomingMessage } from 'node:http'
import type { Plugin, WebSocketClient } from 'vite'
import { SERVER_HOST, SERVER_PORT } from '../../env'
import type { IResponsePayloadFileSwitch } from '../../shared/types'
import { ServerCustomEventType } from '../../shared/types'
import { toSearch } from '../../shared/util'
import state from '../state'
import { sleep } from '../util/misc'
import { openBrowser } from '../util/open'
import { getAuthToken, verifyAuthToken } from './api/jwt'

const plugin = (): Plugin => {
  return {
    name: '@guanghechen/ws',
    configureServer(server) {
      const tokens = new Map<WebSocketClient['socket'], string>()
      const onConnection = (socket: WebSocketClient['socket'], req: IncomingMessage): void => {
        const token = getAuthToken(req.headers)
        if (!token) return
        try {
          verifyAuthToken(token)
          tokens.set(socket, token)
          socket.once('close', () => tokens.delete(socket))
        } catch {
          // Unauthenticated connections may receive HMR, but never file events.
        }
      }
      server.ws.on('connection', onConnection)
      const logoutSubscription = state.authLogout$.subscribe(
        new Subscriber({
          onNext(token) {
            for (const [socket, credential] of tokens) {
              if (credential === token) tokens.delete(socket)
            }
          },
        }),
      )
      const sendFileEvent = (message: {
        type: 'custom'
        event: ServerCustomEventType
        data: IResponsePayloadFileSwitch
      }): void => {
        for (const client of server.ws.clients) {
          const token = tokens.get(client.socket)
          if (!token) continue
          try {
            // Validate again so an open connection cannot outlive its JWT.
            verifyAuthToken(token)
          } catch {
            tokens.delete(client.socket)
            continue
          }
          client.send(message)
        }
      }
      server.httpServer?.once('close', () => {
        server.ws.off('connection', onConnection)
        logoutSubscription.unsubscribe()
        changeSubscription.unsubscribe()
        switchSubscription.unsubscribe()
        tokens.clear()
      })
      const changeSubscription = state.fileChanged$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              const payload: IResponsePayloadFileSwitch = { filepath }
              sendFileEvent({
                type: 'custom',
                event: ServerCustomEventType.FILE_CHANGED,
                data: payload,
              })
            }
          },
        }),
      )
      const switchSubscription = state.fileSwitch$.subscribe(
        new Subscriber({
          onNext(filepath) {
            if (filepath) {
              const payload: IResponsePayloadFileSwitch = { filepath }

              const force: boolean = state.fileSwitchArgForce$.getSnapshot()
              if (force) {
                void forceOpen()

                async function forceOpen(): Promise<void> {
                  const search = toSearch({ filepath })
                  const url = `https://${SERVER_HOST}:${SERVER_PORT}/file${search}`

                  try {
                    await openBrowser(url, true)
                    await sleep(500)
                    sendFileEvent({
                      type: 'custom',
                      event: ServerCustomEventType.FILE_SWITCHED,
                      data: payload,
                    })
                  } catch (error) {
                    state.reporter.error('Failed to notify the FILE_SWITCHED event. error:', error)
                  }
                }
              } else {
                sendFileEvent({
                  type: 'custom',
                  event: ServerCustomEventType.FILE_SWITCH_ASK,
                  data: payload,
                })
              }
            }
          },
        }),
      )
    },
  }
}

export default plugin
