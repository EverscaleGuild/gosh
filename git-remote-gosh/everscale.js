const { promises: fs } = require('fs')
const { join: pathJoin } = require('path')
const { createHash } = require('crypto')

const { TonClient } = require('@eversdk/core')
const { libNode } = require("@eversdk/lib-node")
TonClient.useBinaryLibrary(libNode)

const pathGoshArtifacts = '../gosh'
const signerNone = { type: 'None' }

let ES_CLIENT
let CURRENT_REPO_NAME
let CURRENT_REPO
let Gosh, Repository, Snapshot, Commit, Blob
let UserWallet = {}

const gitOpCosts = {
    createRepo: 2.7e9,
    createBranch: 0.22e9,
    deleteBranch: 0.11e9,
}

const verbose = (...data) => console.error(...data)
const fatal = (...data) => {
    verbose(...data)
    process.exit(1)
}
async function init(network, repo, goshAddress, credentials = {}) {
    const config = {
        network: {
            endpoints: [network || 'main.ton.dev'],
            // queries_protocol: 'WS',
        },
        defaultWorkchain: 0,
        log_verbose: false,
    }

    ES_CLIENT = new TonClient(config)
    GOSH_ADDR = goshAddress
    CURRENT_REPO_NAME = repo
    
    const promises = ['gosh', 'repository', 'snapshot', 'commit', 'blob'].map(name => loadContract(name))
    promises.push(loadContract('SurfMultisigWallet', './abi'))
    ;[
        Gosh,
        Repository,
        Snapshot,
        Commit,
        Blob,
        UserWallet
    ] = await Promise.all(promises)

    Gosh.address = goshAddress

    if (credentials.address && credentials.keys) {
        UserWallet.address = credentials.address
        UserWallet.keys = credentials.keys
    }
}

async function loadContract(name, dir = pathGoshArtifacts) {
    const fullBaseName = pathJoin(__dirname, dir, name)
    return {
        abi: JSON.parse(await fs.readFile(`${fullBaseName}.abi.json`, 'utf8')),
        //tvc: (await fs.readFile(`${fullBaseName}.tvc`)).toString('base64'),
    }
}

async function runLocal(contract, fn, args = {}) {
    const abi = {
        type: 'Contract',
        value: contract.abi,
    }
    const [account, message] = await Promise.all([
        ES_CLIENT.net.query_collection({
            collection: 'accounts',
            filter: { id: { eq: contract.address } },
            result: 'boc',
        })
        .then(({ result }) => result[0].boc)
        .catch(() => {
            throw Error(`Account with address ${contract.address} NOT found`)
        }),
        ES_CLIENT.abi.encode_message({
            abi,
            address: contract.address,
            call_set: {
                function_name: fn,
                input: args,
            },
            signer: signerNone,
        }).then((result) => result.message),
    ])
    return ES_CLIENT.tvm.run_tvm({ message, account, abi })
}

function call(contract, function_name, input = {}, keys) {
    let signer = signerNone
    if (keys || contract.keys) {
        signer = {
            type: 'Keys',
            keys: keys || contract.keys,
        }
    }
    const params = {
        send_events: false,
        message_encode_params: {
            address: contract.address,
            abi: {
                type: 'Contract',
                value: contract.abi,
            },
            call_set: {
                function_name,
                input,
            },
            signer,
        },
    }
    return ES_CLIENT.processing.process_message(params)
        .then(({ transaction, decoded }) => ({ transaction_id: transaction.id, output: decoded.output }))
        .catch(err => {
            verbose(`ERROR! Contract: ${contract.address}`)
            fatal(err)
        })
}

function createRunBody(contract, function_name, params) {
    return ES_CLIENT.abi.encode_message_body({
        abi: {
            type: 'Contract',
            value: contract.abi
        },
        call_set: {
            function_name,
            input: params,
        },
        is_internal: true,
        signer: signerNone,
    }).then(({ body }) => body)
}

async function callWithWallet(wallet, calledContract, calledFn, calledArgs, value = 1e9) {
    const payload = await createRunBody(calledContract, calledFn, calledArgs)
    const params = {
        dest: calledContract.address,
        value,
        bounce: false,
        allBalance: false,
        payload,
    }
    return call(wallet, 'submitTransaction', params)
}

// Gosh contract
async function getRepoAddress(repoName) {
    if (CURRENT_REPO && CURRENT_REPO.address) return CURRENT_REPO.address
    const result = await runLocal(Gosh, 'getAddrRepository', { name: repoName })
    return result.decoded.output.value0
}

async function getRepo(repoName = CURRENT_REPO_NAME) {
    if (CURRENT_REPO) return CURRENT_REPO
    const repo = {
        ...Repository,
        name: repoName,
        address: await getRepoAddress(repoName)
    }

    const query = {
        collection: 'accounts',
        filter: { id: { eq: repo.address } },
        result: 'acc_type balance',
    }
    const { result } = await ES_CLIENT.net.query_collection(query);

    if (result.length) {
        repo.status = result[0].acc_type
        repo.balance = +result[0].balance
    }

    CURRENT_REPO = repo
    return CURRENT_REPO
}

function createRepo(name) {
    return callWithWallet(UserWallet, Gosh, 'deployRepository', { name }, gitOpCosts.createRepo)
}

// Repo contract
async function createBranch(name, from, repo = CURRENT_REPO_NAME) {
    const repoContract = await getRepo(repo)
    return callWithWallet(
        UserWallet,
        repoContract,
        'deployBranch',
        { newname: name, fromname: from },
        gitOpCosts.createBranch,
    )
}

async function deleteBranch(name, repo = CURRENT_REPO_NAME) {
    const repoContract = await getRepo(repo)
    return callWithWallet(
        UserWallet,
        repoContract,
        'deleteBranch',
        { name },
        gitOpCosts.deleteBranch
    )
}

async function branchList(repo = CURRENT_REPO_NAME) {
    const repoContract = await getRepo(repo)
    const rawList = (await runLocal(repoContract, 'getAllAddress')).decoded.output.value0
    const list = rawList.filter(({ value }) => value)
    if (list.length === 0) return []

    const promises = list.map(async ({ value: commitAddr }) => getCommitByAddr(commitAddr))
    return Promise.all(promises).then((result) => {
        return result.map((v, i) => ({
            repo: v.repo,
            branch: v.branch,
            sha: v.sha,
            address: list[i].value,
            snapshot: list[i].snapshot,
        }))
    })
}


function getRemoteHead(repo = CURRENT_REPO_NAME) {
    return 'refs/heads/master'
}

async function createCommit(branch, sha, content) {
    const repoContract = await getRepo(CURRENT_REPO_NAME)
    return call(repoContract, 'deployCommit', { nameBranch: branch, nameCommit: sha, fullCommit: content })
}

async function getCommitAddr(sha, branch = 'master') {
    const repoContract = await getRepo(CURRENT_REPO_NAME)
    const result = await runLocal(repoContract, 'getCommitAddr', { nameBranch: branch, nameCommit: sha })
    return result.decoded.output.value0
}

// Commit contract
async function getCommitByAddr(commitAddr) {
    const commitContract = { ...Commit, address: commitAddr }
    const result = await runLocal(commitContract, 'getCommit')
    const [repo, _branch, _id, parent, content] = Object.values(result.decoded.output)
    return {
        repo,
        branch: _branch,
        sha: _id,
        parent,
        content,
    }
}

async function getCommit(sha, branch = 'master') {
    const commitAddr = await getCommitAddr(sha, branch)
    return { type: 'commit', address: commitAddr, ...(await getCommitByAddr(commitAddr)) }
}

function createBlob(sha, type, commitAddr, content) {
    const commitContract = { ...Commit, address: commitAddr }
    return call(commitContract, 'deployBlob', { nameBlob: `${type} ${sha}`, fullBlob: content })
}

async function getBlobAddr(sha, type, commitAddr) {
    const commitContract = { ...Commit, address: commitAddr }
    const result = await runLocal(commitContract, 'getBlobAddr', { nameBlob: `${type} ${sha}` }).catch(e => fatal(e.message))
    return result.decoded.output.value0
}

async function listBlobs(commitAddr) {
    const commitContract = { ...Commit, address: commitAddr }
    const result = await runLocal(commitContract, 'getBlobs')
    return result.decoded.output
}

// Blob contract
async function getBlob(sha, type, commitAddr) {
    const blobAddr = await getBlobAddr(sha, type, commitAddr).catch(e => fatal(e.message))
    const blobContract = { ...Blob, address: blobAddr }
    const result = await runLocal(blobContract, 'getBlob').catch(e => fatal(e.message))
    return result.decoded.output
}

// other
async function createTree(commit, id, content) {
    const repoContract = await getRepo(CURRENT_REPO_NAME)

}

async function calcCommitAddress(branch, sha) {
    /* const repoContract = await getRepo()
    const rawCode = (await runLocal(repoContract, 'getCommitCode')).decoded.output.value0
    const builder = [
        { type: 'Address', address: repoContract.address },
        { type: 'BitString', value: `x${utf8ToHex(branch)}`},
        { type: 'BitString', value: `x${utf8ToHex('0.0.1')}` },
    ]
    const { boc: salt } = await ES_CLIENT.boc.encode_boc({ builder })
    const { code: saltedCode } = await ES_CLIENT.boc.set_code_salt({ code: rawCode, salt })
    const { data } = await ES_CLIENT.abi.encode_initial_data({
        abi: { type: 'Contract', value: Commit.abi },
        initial_data: { _nameCommit: sha }
    })
    const { tvc } = await ES_CLIENT.boc.encode_tvc({ code: saltedCode, data })
    const { hash } = await ES_CLIENT.crypto.sha256({ data: tvc })
    verbose({ hash }) */
    return null
}

function sha1(data, type = 'blob') {
    let content = data
    if (type === 'commit') content += '\n'
    const size = Buffer.byteLength(content, 'utf-8')
    const object = `${type} ${size}\0${content}`
    const hash = createHash('sha1')
    hash.update(object)
    return hash.digest('hex')
}

// global vars wrappers
const goshContract = () => Gosh
const currentRepo = () => CURRENT_REPO_NAME
const userWallet = () => UserWallet

module.exports = {
    init,
    sha1,
    createRepo,
    getRepoAddress,
    getRepo,
    createBranch,
    deleteBranch,
    branchList,
    getRemoteHead,
    createCommit,
    getCommitAddr,
    getCommitByAddr,
    getCommit,
    createBlob,
    getBlobAddr,
    listBlobs,
    getBlob,
    // global vars
    goshContract,
    currentRepo,
    userWallet,
}