#!/usr/bin/env node

const { promises: fs } = require('fs')
const { join: pathJoin } = require('path')
const readline = require('readline')

const {
    setVerboseFlag,
    setProgressFlag,
    setDryRunFlag,
    getProgressFlag,
    getDryRunFlag,
    verbose,
    fatal,
    send,
    deconstructRemoteUrl,
    emoji_shrug,
} = require('./utils')
const helper = require('./everscale')
const git = require('./git')

// TODO: remove hardcode
const GOSH = '0:36765cc695d7bd410a976666d666aee15373205a7c5b9d15a83c301b9c0d7ad7'
const CAPABILITIES_LIST = ['list', 'push', 'fetch']

let firstPush
const _remoteRefs = {} // remote refs: ref_name => sha1, addr
const _pushed = {} // pushed refs
const received = []

function accountRequired() {
    verbose('error: account credentials required')
    verbose('info: To be able to push to Gosh repositories, you need to have a wallet on the Everscale blockchain. Helper expects that the wallet credentials are in the file: `~/.gosh/credentials.json`')
    process.exit(1)
}

async function loadCredentials() {
    const homedir = process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE
    const credentialFile = pathJoin(homedir, '.gosh', 'credentials.json')
    const content = await fs.readFile(credentialFile, 'utf-8')
        .catch(err => {
            if (err.code === 'ENOENT') verbose(`warning: credential file (${credentialFile}) not found`)
            return "{}"
        })
    let credentials
    try {
        credentials = JSON.parse(content)
    } catch (err) {
        fatal(`Failed to parse credentials file ${credentialFile}\n${err.code}`)
    }
    return credentials
}

const userCredentials = async (account) => (await loadCredentials())[account]

async function getRefs() {
    const branches = await helper.branchList()
    return branches.reduce((acc, { branch, address, sha }) => {
        if (address) {
            _remoteRefs[branch] = { address, sha }
            acc.push(`${sha} refs/heads/${branch}`)
        }
        return acc
    }, [])
}

function objectData(object) {
    return Promise.all([
        git.typeObject(object),
        git.catObject(object),
    ]).then(([type, content]) => ({ type, content }))
    /* return {
        type: git.typeObject(object),
        content: git.catObject(object)
    } */
}

async function deleteRemoteRef(ref) {
    verbose('WARN: delete branch not implemented yet')
}

async function pushObject(sha, currentCommit, branch) {
    const { type, content } = await objectData(sha)
    // verbose(`debug: object ${type} "${content}"`)
    if (type === 'commit') {
        const address = await helper.getCommitAddr(sha, branch)
        currentCommit = { sha, address }
        // verbose('debug: set current commit:', currentCommit)
        const result = await helper.createCommit(branch, sha, content)
        verbose(`debug: uploading ${type}(${sha}): ${address}`)
    } else {
        const result = await helper.createBlob(sha, type, currentCommit.address, content)
        const address = await helper.getBlobAddr(sha, type, currentCommit.address)
        verbose(`debug: uploading ${type}(${sha}): ${address}`)
    }
    verbose(`debug: writing: ${sha} (${type})`)
    return currentCommit
}

async function pushRef(localRef, remoteRef) {
    //return new Promise(async (resolve) => {
    let result
    try {
        const branch = localRef.slice('refs/heads/'.length)
        // verbose(`debug: pushRef(${localRef}, ${remoteRef})`)
        const exists = Object.values(_remoteRefs).map(ref => ref.sha)
        const output = await git.lsObjects(localRef, exists)
        // verbose(`debug: listed ${output.length} object(s):`)
        // verbose(output)
        const objects = output.map(o => o.split(' ')[0])

        let currentCommit = {}
        for (let sha of objects) {
            currentCommit = await pushObject(sha, currentCommit, branch)
        }
        _pushed[remoteRef] = currentCommit.sha
        // resolve(`error ${remoteRef} ${emoji_shrug}`)
        result = `ok ${remoteRef}`
    } catch (err) {
        verbose('debug: Error!', err.message)
        result = `error ${remoteRef} ${emoji_shrug}`
    }
    return result
    //})
}

function doCapabilities() {
    CAPABILITIES_LIST.forEach(cap => send(cap))
    send()
}

function doOption(input) {
    const [, optName, optValue] = input.split(' ')
    if (optName === 'verbosity') {
        send('ok')
        setVerboseFlag(optValue)
        return
    // } else if (optName === 'progress') {
    //     setProgressFlag(optName)
    // } else if (optName === 'dry-run') {
    //     setDryRunFlag(optValue)
    }
    send('unsupported')
}

async function doList(forPush = false) {
    const refs = await getRefs()
    // verbose('debug: remote refs:', refs)
    // verbose('debug: remote refs:', _remoteRefs)
    refs.forEach(ref => send(ref))

    if (!forPush) {
        const remoteHead = helper.getRemoteHead()
        send(`@${remoteHead} HEAD`)
    }
    send()
}

async function doPush(input) {
    const [localRef, remoteRef] = input.split(' ')[1].split(':')
    if (!localRef) {
        const deleteResult = await deleteRemoteRef(remoteRef)
        // verbose('debug: delete result:', deleteResult)
        send(deleteResult)
    } else {
        const pushResult = await pushRef(localRef, remoteRef)
        // verbose('debug: push result:', pushResult)
        send(pushResult)
    }
}

async function doFetch(input) {
    const [, commitSha, ref] = input.split(' ')
    const branch = ref.slice('refs/heads/'.length)
    
    const queue = [{ type: 'commit', sha: commitSha }]
    const notQueued = obj => !queue.find(elem => elem.sha === obj.sha)
    // const received = []
    const serializationQueue = []
    const commits = {}

    const promises = []
    while (queue.length) {
        const { type, sha, commit } = queue.shift()
        if (received.includes(sha)) continue
        if (serializationQueue.includes(sha)) continue
        // if (await git.isExistsObject(sha)) {
        //     verbose(`debug: already downloaded: ${sha}`)
        // } else {
            if (type === 'commit') {
                const object = await helper.getCommit(sha, branch)
                verbose(`debug: got: ${sha}`)
                commits[object.sha] = object
                const refList = git.extractRefs(type, object.content)
                    .map(o => ({ ...o, commit: sha }))
                    .filter(notQueued)
                queue.push(...refList)
                // verbose('debug: after load commit:', queue)
                if (!serializationQueue.includes(sha)) {
                    promises.push(git.writeObject(type, object.content, { sha }))
                    serializationQueue.push(sha)
                }
            } else if (type === 'tag') {
                verbose(`debug: warning: retrieving ${type}-object not supported yet`)
                continue
            } else {
                const commitAddr = commits[commit]
                    ? commits[commit].address
                    : await helper.getCommitAddr(commit, branch)
                const object = await helper.getBlob(sha, type, commitAddr)
                verbose(`debug: got: ${sha}`)
                const refList = git.extractRefs(type, object.content)
                    .map(o => ({ ...o, commit }))
                    .filter(notQueued)
                queue.push(...refList)
                // verbose(`debug: after load ${type}:`, queue)
                // verbose({ type, sha, content: object.content })
                if (!serializationQueue.includes(sha)) {
                    promises.push(git.writeObject(type, object.content, { sha }))
                    serializationQueue.push(sha)
                }
            }
            // received.push(sha)
            // verbose(`debug: wrote: ${sha}`)
        // }
    }
    verbose(`collected ${promises.length} objects`)
    await Promise.all(promises).then(values => {
        values.forEach(sha => {
            received.push(sha)
            verbose(`wrote: ${sha}`)
        })
    }, reason => fatal('doFetch() error:', reason))
    send()
    return Promise.resolve()
}

;(async () => {
    const startTime = process.hrtime.bigint()
    const args = process.argv.slice(2)

    if (args.length !== 2) {
        fatal('Expected 2 arguments')
    }

    const [, remoteUrl] = args
    const context = deconstructRemoteUrl(remoteUrl)
    
    const credentials = await userCredentials(context.account)

    await helper.init(context.network, context.repo, context.gosh, credentials)

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false
    })

    for await (const input of rl) {
        verbose(`> ${input}`)
        if (input === 'capabilities') {
            doCapabilities()
        } else if (input === 'option') {
            // list of possible options: https://git-scm.com/docs/gitremote-helpers#_options
            doOption(input)
        } else if(input === 'list') {
            await doList()
        } else if (input === 'list for-push') {
            if (!helper.userWallet().address) accountRequired()
            await doList(true)
        } else if (input.startsWith('push')) {
            if (!helper.userWallet().address) accountRequired()
            await doPush(input)
        } else if (input.startsWith('fetch')) {
            await doFetch(input)
            //} else if (input.startsWith('connect')) {
                //    verbose(`> ${input}`)
                //    const [, arg] = input.split(' ')
                //    const result = await execCmd(`${arg} ${context.repo}`)
                //    verbose('[DEBUG] stdout:', result)
                //    send(result)
            } else if (input === '') { // finish communication
                send()
                const endTime = process.hrtime.bigint()
                verbose(`completed in ${(endTime - startTime) / BigInt(1e9)} sec`)
                process.exit(0)
            } else {
                verbose(`remote: got unknown command: "${input}"`)
                process.exit(1)
            }
        }
})()