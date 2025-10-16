@lua/std/git.lua @lua/eve/state/git.lua 

1. Let's maintain a git status table, in the git status table, we can known which file are modified, added, deleted, staged, unstaged and etc. keep in mind that a file could below both the `staged` and `unstaged` status, for example, if we changed a file and staged the changes and then modify it again without staged it.

2. We can declare a function `refresh_git_status` to update the git status table mentioned above, this function can collect the status data by git commands, then let's  create a scheduler task to refresh the git status table periodically (e.g. every 5 minutes), but the `refresh_git_status` function also should expose from the module so we can trigger it manually when needed. 

3. Then, let's consider to watch the file changes under the git repository, and each got notified of file changes, let's trigger a `refresh_git_status`. For performance concern, we should debounce the `refresh_git_status` calls, for example, if we got multiple file change notifications within a short period (e.g. 3 second), we should only call `refresh_git_status` once after the last notification.

4. If a file has multiple status (e.g. staged and unstaged), we should show all the status character beside of the file item, but use the priority to set the color, for example, deleted > unstaged > staged > modified > added, so if a file is both staged and unstaged, we should use the unstaged color to highlight the filename, but for the status character, it should still use it's owned color.

