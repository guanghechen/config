import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import test from 'node:test'
import { COMMAND_IDS, VIEW_IDS } from '../src/platform/extension-ids'

interface IManifestCommand {
  readonly command: string
}

interface IManifestView {
  readonly id: string
  readonly type?: string
}

interface IManifestViewContainer {
  readonly id: string
  readonly icon: string
}

interface IExtensionManifest {
  readonly activationEvents: ReadonlyArray<string>
  readonly contributes: {
    readonly commands: ReadonlyArray<IManifestCommand>
    readonly menus: Readonly<Record<string, ReadonlyArray<IManifestCommand>>>
    readonly views: Readonly<Record<string, ReadonlyArray<IManifestView>>>
    readonly viewsContainers: {
      readonly activitybar: ReadonlyArray<IManifestViewContainer>
    }
  }
}

const REPOSITORY_PATH = process.cwd()
const manifest = JSON.parse(
  readFileSync(path.join(REPOSITORY_PATH, 'package.json'), 'utf8'),
) as IExtensionManifest

test('declares a valid VSGit Activity Bar container and views', () => {
  const containers = manifest.contributes.viewsContainers.activitybar
  for (const container of containers) {
    assert.match(container.id, /^[A-Za-z0-9_-]+$/)
    assert.ok(existsSync(path.join(REPOSITORY_PATH, container.icon)))
  }

  const container = containers.find(candidate => candidate.id === 'vsgit-sidebar')
  assert.ok(container)
  assert.deepEqual(
    manifest.contributes.views[container.id]?.map(view => view.id),
    [VIEW_IDS.commits, VIEW_IDS.historySearch, VIEW_IDS.comparison],
  )
  assert.equal(
    manifest.contributes.views[container.id]?.find(view => view.id === VIEW_IDS.historySearch)
      ?.type,
    'webview',
  )
})

test('declares commit browser commands, menus, and view activation', () => {
  const commandIds = manifest.contributes.commands.map(command => command.command)
  assert.equal(new Set(commandIds).size, commandIds.length)

  const expectedCommandIds = Object.values(COMMAND_IDS).filter(
    command => command !== COMMAND_IDS.focusComparison,
  )
  assert.deepEqual(new Set(commandIds), new Set(expectedCommandIds))

  const menuCommands = Object.values(manifest.contributes.menus).flatMap(items =>
    items.map(item => item.command),
  )
  for (const command of menuCommands) assert.ok(commandIds.includes(command), command)
  assert.ok(manifest.activationEvents.includes(`onView:${VIEW_IDS.historySearch}`))
  assert.ok(manifest.activationEvents.includes(`onView:${VIEW_IDS.commits}`))
  assert.ok(manifest.activationEvents.includes(`onCommand:${COMMAND_IDS.searchCommits}`))
})
