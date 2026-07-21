export const COMMAND_IDS = Object.freeze({
  clearCommitSearch: 'vsgit.clearCommitSearch',
  clearCommitMarks: 'vsgit.clearCommitMarks',
  clearComparison: 'vsgit.clear',
  compareCommitToHead: 'vsgit.compareCommitToHead',
  compareMarkedCommits: 'vsgit.compareMarkedCommits',
  compareReferences: 'vsgit.compareRefs',
  compareWithMarkedCommit: 'vsgit.compareWithMarkedCommit',
  focusComparison: 'vsgit.changes.focus',
  loadMoreCommits: 'vsgit.loadMoreCommits',
  markCommit: 'vsgit.markCommit',
  openCommitFileDiff: 'vsgit.openCommitFileDiff',
  openComparisonDiff: 'vsgit.openDiff',
  refreshCommits: 'vsgit.refreshCommits',
  refreshComparison: 'vsgit.refresh',
  searchCommits: 'vsgit.searchCommits',
  selectRepository: 'vsgit.selectRepository',
  swapComparisonReferences: 'vsgit.swapRefs',
  unmarkCommit: 'vsgit.unmarkCommit',
})

export const CONTEXT_KEYS = Object.freeze({
  canCompareMarkedCommits: 'vsgit.canCompareMarkedCommits',
  hasCommitHistory: 'vsgit.hasCommitHistory',
  hasCommitMarks: 'vsgit.hasCommitMarks',
  hasCommitSearch: 'vsgit.hasCommitSearch',
  hasComparison: 'vsgit.hasComparison',
  hasOneCommitMark: 'vsgit.hasOneCommitMark',
})

export const VIEW_IDS = Object.freeze({
  commits: 'vsgit.commits',
  comparison: 'vsgit.changes',
  historySearch: 'vsgit.historySearch',
})

export const VIEW_ITEM_CONTEXT_VALUES = Object.freeze({
  commit: 'vsgit.commit',
  commitDirectory: 'vsgit.commitDirectory',
  commitError: 'vsgit.commitError',
  commitFile: 'vsgit.commitFile',
  commitMarked: 'vsgit.commitMarked',
  comparisonDirectory: 'vsgit.directory',
  comparisonFile: 'vsgit.file',
  loadMoreCommits: 'vsgit.loadMoreCommits',
})
