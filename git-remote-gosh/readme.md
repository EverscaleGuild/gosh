git-remote-gosh is a git-client helper to interact with remote repositories hosted on the Everscale blockchain networks

--

This Git helper used Everscale blockchain as a remote for Git.

## Remote

For correct usage of the helper you should use remote in form:

```
gosh[::<NETWORK>]://[<USER_ACCOUNT>@]GOSH_ROOT/REPO_NAME
```

Defaults values are following:

**NETWORK** - `main.ton.dev`

**USER_ACCOUNT** - `default`


### Examples:

For usage with local (Evernode SE)[https://github.com/tonlabs/evernode-se] remote may be as follows:

```
gosh::localhost://0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/my-user-name/my-repo
```

## User account

To be able to push to Gosh repositories, you need to have a wallet on the Everscale blockchain. git-remote-gosh expects that the wallet credentials are in the file: `~/.gosh/credentials.json`:

```json
{
    "my-wallet": {
        "address": "0:d5f5cfc4b52d2eb1bd9d3a8e51707872c7ce0c174facddd0e06ae5ffd17d2fcd",
        "keys": {
            "public": "1234567890123456789012345678901234567890123456789012345678901234",
            "secret": "0987654321098765432109876543210987654321098765432109876543210987"
        }
    }
}
```

For usage of this wallet (main network as default) the remote may be as follows:

```
gosh://my-wallet@0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/my-user-name/my-repo
```

## Setup helper

1. Prerequisites:
   1. `node` (NodeJS) and matching `npm`
   2. `git`
2. Clone `git-remote-gosh` repo and install dependencies with `npm i`
3. Add path with `git-remote-helper` for availability via `$PATH` or symlinked it (e.g. `/usr/local/bin`). Use `which git-remote-gosh` to make sure it's available.

### For existing local repository

To set a remote to an existing local repository:

```sh
git remote add origin gosh::net.ton.dev://my-wallet@0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/my-user-name/my-repo
```

### For a new Gosh repository

To clone repositories you should add 

```sh
git clone gosh::net.ton.dev://my-wallet@0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/my-user-name/my-repo
```

### Ever SDK protocol

By default, the SDK uses the WebSocket protocol. If for some reason this does not suit you (for example, you are using Alpine Linux), then set the environment variable `GOSH_PROTO` to `http`

```sh
export GOSH_PROTO=http
```