#!/usr/bin/env bash
# Tests git-bash/.bashrc in a throwaway HOME: first interactive shell starts
# an agent and loads the key, a second shell reuses the same agent, a stale
# agent.env leads to a fresh agent. Runs on Linux and in Git Bash.
set -u
here=$(cd "$(dirname "$0")" && pwd)
rc="$here/../git-bash/.bashrc"
fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }

bash -n "$rc"; check "syntax" '[ $? = 0 ]'

tmp=$(mktemp -d)
cleanup() {
    [ -f "$tmp/.ssh/agent.env" ] && (. "$tmp/.ssh/agent.env" >/dev/null; ssh-agent -k >/dev/null 2>&1)
    rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/.ssh"
ssh-keygen -q -t ed25519 -N '' -C test -f "$tmp/.ssh/id_test"

# Run an interactive shell with the rc, print agent pid and loaded key count.
probe() {
    env -i HOME="$tmp" PATH="$PATH" SSH_AGENT_KEYS="id_test" \
        bash --noprofile --rcfile "$rc" -i -c \
        'echo "$SSH_AGENT_PID $(ssh-add -l 2>/dev/null | wc -l)"' 2>/dev/null
}

read -r pid1 n1 < <(probe)
check "first shell starts an agent" '[ -n "$pid1" ] && kill -0 "$pid1" 2>/dev/null'
check "first shell loads the key" '[ "$n1" = 1 ]'

read -r pid2 n2 < <(probe)
check "second shell reuses the agent" '[ "$pid2" = "$pid1" ]'
check "key still loaded, not added twice" '[ "$n2" = 1 ]'

kill "$pid1"; sleep 0.2
read -r pid3 n3 < <(probe)
check "stale agent.env -> fresh agent" '[ -n "$pid3" ] && [ "$pid3" != "$pid1" ] && [ "$n3" = 1 ]'

perm=$(stat -c %a "$tmp/.ssh/agent.env" 2>/dev/null)
check "agent.env is private (600)" '[ "$perm" = 600 ]'

out=$(env -i HOME="$tmp" PATH="$PATH" bash --noprofile --rcfile "$rc" -c 'echo noninteractive' 2>&1)
check "non-interactive shell is silent" '[ "$out" = noninteractive ]'

exit $fail
