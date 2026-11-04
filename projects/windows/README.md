# windows

Setup snippets for working on Windows with Git for Windows (Git Bash).

**Owner:** sokrates · **Status:** tested on Linux bash; not yet run in Git Bash on Windows

## Contents

| File | What |
|---|---|
| `git-bash/.bashrc` | One shared `ssh-agent` for all Git Bash windows: started once, reused by every new window, passphrase asked once per login session |
| `test/test_bashrc.sh` | Test for the `.bashrc` in a throwaway `HOME` |

## Install: ssh-agent for Git Bash

1. Check where Git Bash's home is: `echo $HOME`. On company PCs this is often a
   network drive (`/h`). Private keys don't belong there; point `HOME` at the
   local profile (no admin needed), then open a new Git Bash window:
   ```bash
   setx HOME "$USERPROFILE"
   ```
2. Copy the file (or append it to an existing `~/.bashrc`):
   ```bash
   cp git-bash/.bashrc ~/.bashrc
   ```
3. Choose the keys to load: edit the `SSH_AGENT_KEYS` line, e.g.
   `SSH_AGENT_KEYS="${SSH_AGENT_KEYS:-id_gitlab_work}"`. Empty = `ssh-add`'s defaults.
4. Git must use its own `ssh` (the one that talks to this agent), not the Windows
   OpenSSH one. Remove a leftover override if you set one:
   ```bash
   git config --global --unset core.sshCommand
   ```
5. Open a new Git Bash window: the passphrase is asked once. Verify:
   ```bash
   ssh-add -l
   ssh -T git@gitlab.com
   ```

Git Bash runs a login shell that reads `~/.bash_profile`; Git for Windows creates
one that sources `~/.bashrc` if it's missing. If you have your own
`~/.bash_profile`, make sure it contains `[ -f ~/.bashrc ] && . ~/.bashrc`.

How it works: the agent's address is written to `~/.ssh/agent.env` (mode 600).
Every new interactive shell loads it and asks the agent (`ssh-add -l`): keys
present → nothing to do; agent alive but empty → add keys; agent gone (logout,
reboot, killed) → start a new one. Non-interactive shells (scp, rsync, hooks)
are left alone.

This agent is visible only to Git Bash. PowerShell, VS Code and the Windows
OpenSSH client use the Windows `ssh-agent` service instead.

## Test

```bash
./test/test_bashrc.sh
```

Needs `bash`, `ssh-agent`, `ssh-add`, `ssh-keygen` (all included in Git for Windows).
