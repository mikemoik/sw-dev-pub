# ~/.bashrc for Git Bash (Git for Windows)
#
# Starts ONE ssh-agent and shares it between all Git Bash windows, so the
# key passphrase is asked once per login session, not once per window.
# The agent's address is kept in ~/.ssh/agent.env; a new window reuses the
# agent if it is still alive, otherwise starts a fresh one.
#
# Keys: list the private keys to load in SSH_AGENT_KEYS (space-separated,
# relative to ~/.ssh or absolute). Empty = ssh-add's defaults (id_ed25519,
# id_rsa, ...).

SSH_AGENT_KEYS="${SSH_AGENT_KEYS:-}"     # e.g. "id_gitlab_work id_github"

# Only for interactive shells (scp/rsync/git hooks must not prompt).
case $- in *i*) ;; *) return ;; esac

__agent_env=~/.ssh/agent.env

__agent_load_env() {
    [ -f "$__agent_env" ] && . "$__agent_env" >/dev/null
}

__agent_start() {
    mkdir -p ~/.ssh
    (umask 077; ssh-agent -s >"$__agent_env")
    . "$__agent_env" >/dev/null
}

__agent_add_keys() {
    if [ -z "$SSH_AGENT_KEYS" ]; then
        ssh-add
        return
    fi
    local k
    for k in $SSH_AGENT_KEYS; do
        case $k in /*|~*) ;; *) k=~/.ssh/$k ;; esac
        ssh-add "$k"
    done
}

__agent_load_env

# ssh-add -l exit code: 0 = agent has keys, 1 = agent has no keys,
# 2 = no agent reachable (stale or missing agent.env).
ssh-add -l >/dev/null 2>&1
case $? in
    2) __agent_start; __agent_add_keys ;;
    1) __agent_add_keys ;;
esac

unset -f __agent_load_env __agent_start __agent_add_keys
unset __agent_env
