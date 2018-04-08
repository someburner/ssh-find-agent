# ssh-find-agent

`ssh-find-agent` is a tool for locating existing ssh compatible agent processes
(e.g., ssh-agent, gpg-agent, gnome-keyring); and, optionally, setting `SSH_AUTH_SOCK` accordingly.

## Usage

Somewhere in shell initialization (`~/.bashrc` or `~./.zshrc`)

```sh
. ssh-find-agent.sh
```

Add the following to automatically choose the first agent

```sh

ssh-find-agent -a
if [[ -z "$SSH_AUTH_SOCK" ]]; then
	eval $(ssh-agent) > /dev/null;
	ssh-add -l >/dev/null || alias ssh='ssh-add -l >/dev/null || ssh-add && unalias ssh; ssh';
fi
```

... or, as `ssh-find-agent` with `-a` or `-c` returns non-zero if it cannot find a live-agent, simply:

```sh
ssh-find-agent -a || eval $(ssh-agent) > /dev/null
```

To choose the agent manually run

```sh
ssh-find-agent -c
```

To list the agents run:

```sh
ssh-find-agent
```

## Alternatives

  * [keychain](https://github.com/funtoo/keychain)
  * [envoy](https://github.com/vodik/envoy)
