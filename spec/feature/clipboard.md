## Task Background
I want to enable OSC 52 clipboard in tmux like what the zellij terminal multiplexer does.

Consider below situation: There have two user on the macos system (the latest version, 26.0.1), Alice and Bob.

1. Alice is logged in the GUI and running terminal.
2. Alice is switched to Bob in the terminal (tty) using `sudo su Bob`.
3. Now, the terminal user is the Bob, then Bob is running tmux.
4. In the tmux, Bob runs `echo -n "hello world" | pbcopy` to copy "hello world" to clipboard, but it does not work.

If Bob runs the zellij terminal multiplexer instead of tmux, then the `echo -n "hello world" | pbcopy` works and "hello world" is copied to clipboard. That's the issue I want to solve.

## Task Details

1. I want the Bob can access the system clipboard under the Alice's GUI session, in particularly, when Bob copied things from the terminal, it should be able to paste into the Alice GUI through the system clipboard like things copied by Alice.
2. I only want the solution works in local terminal, not in ssh session.

