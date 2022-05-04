const { promises: fs } = require('fs')
const { join: pathJoin } = require('path')
const { createHash } = require('crypto')

const { TonClient } = require('@eversdk/core')
const { libNode } = require("@eversdk/lib-node")
TonClient.useBinaryLibrary(libNode)

const { verbose, fatal } = require('./utils')
const pathGoshArtifacts = '../gosh'
const signerNone = { type: 'None' }
const ZERO_ADDRESS = '0:0000000000000000000000000000000000000000000000000000000000000000'
const FEE_SET_COMMIT = 3e8

let ES_CLIENT
let CURRENT_DAO
let CURRENT_REPO_NAME
let CURRENT_REPO
let Gosh, Repository, Commit, Blob, Dao, Tag
let UserWallet = {}

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
    
    const [dao, ...tail] = repo.split('/')
    if (!tail) fatal(`Incorrect repo name: ${repo}. DAO not found`)
    CURRENT_DAO = dao
    CURRENT_REPO_NAME = tail.join('/')
    
    const promises = ['gosh', 'repository', 'commit', 'blob', 'goshdao', 'tag'].map(name => loadContract(name))
    promises.push(loadContract('goshwallet', './abi'))
    ;[
        Gosh,
        Repository,
        Commit,
        Blob,
        Dao,
        Tag,
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

async function waitTrxCompletion(transaction) {
    await ES_CLIENT.net.query_transaction_tree({in_msg: transaction.in_msg, timeout: 60000 * 5})
}

function call(contract, function_name, input = {}, keys, wait = false) {
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
        .then(async ({ transaction, decoded }) => {
            if (wait) {
                process.stderr.write(`waiting trx ${transaction.id}... `)
                await waitTrxCompletion(transaction)
                console.error('ok')
            }
            return { transaction_id: transaction.id, output: decoded.output }
        })
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

/* async function callWithWallet(wallet, calledContract, calledFn, calledArgs, value = 1e9) {
    const payload = await createRunBody(calledContract, calledFn, calledArgs)
    const params = {
        dest: calledContract.address,
        value,
        bounce: false,
        allBalance: false,
        payload,
    }
    return call(wallet, 'submitTransaction', params)
} */

/* // DAO
async function getAddrDao() {
    const result = await runLocal(Gosh, 'getAddrDao', { name: CURRENT_DAO }).catch(err => fatal(err))
    return result.decoded.output.value0
} */

// Gosh contract
async function getRepoAddress(repoName) {
    if (CURRENT_REPO && CURRENT_REPO.address) return CURRENT_REPO.address
    // const dao = await getAddrDao()
    const result = await runLocal(Gosh, 'getAddrRepository', { name: repoName, dao: CURRENT_DAO }).catch(err => fatal(err))
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
    return call(UserWallet, 'deployRepository', { name })
}

// Repo contract
async function createBranch(name, from, repoName = CURRENT_REPO_NAME) {
    // const repoContract = await getRepo(repoName)
    return call(
        UserWallet,
        'deployBranch',
        { repoName, newName: name, fromName: from },
    )
}

async function deleteBranch(name, repo = CURRENT_REPO_NAME) {
    const repoContract = await getRepo(repo)
    return call(UserWallet, 'deleteBranch', { name })
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

async function getBranch(name) {
    const repoContract = await getRepo(CURRENT_REPO_NAME)
    return runLocal(repoContract, 'getAddrBranch', { name }).then(({ decoded }) => decoded.output.value0.value)
}

function getRemoteHead(repo = CURRENT_REPO_NAME) {
    return 'refs/heads/main'
}

async function createCommit(branch, sha, content) {
    const promises = []
    for (const line of content.split('\n')) {
        const [key, value] = line.split(' ', 2)
        if (key === 'parent') {
            promises.push(getCommitAddr(value, branch))
        }
    }
    const parents = await Promise.all(promises)
    return call(UserWallet, 'deployCommit', {
        repoName: CURRENT_REPO_NAME,
        branchName: branch,
        commitName: sha,
        fullCommit: content,
        parents,
    })
}

async function getCommitAddr(sha, branch) {
    const repoContract = await getRepo(CURRENT_REPO_NAME)
    const result = await runLocal(repoContract, 'getCommitAddr', { nameBranch: branch, nameCommit: sha }).catch(err => fatal(err))
    return result.decoded.output.value0
}

// Commit contract
async function getCommitByAddr(commitAddr) {
    const commitContract = { ...Commit, address: commitAddr }
    const result = await runLocal(commitContract, 'getCommit')
    const [repo, _branch, _id, parents, content] = Object.values(result.decoded.output)
    return {
        repo,
        branch: _branch,
        sha: _id,
        parents,
        content,
    }
}

async function getCommit(sha, branch = 'main') {
    const commitAddr = await getCommitAddr(sha, branch)
    return { type: 'commit', address: commitAddr, ...(await getCommitByAddr(commitAddr)) }
}

function setCommit(branch, branchCommit, commit, depth) {
    const value = FEE_SET_COMMIT + FEE_SET_COMMIT * depth
    return call(UserWallet, 'setCommit', {
        repoName: CURRENT_REPO_NAME,
        branchName: branch,
        branchcommit: branchCommit === ZERO_ADDRESS ? '' : branchCommit,
        commit,
        value,
    })
}

function createBlob(sha, type, commitSha, prevSha, branch, content) {
    return compress(content).then(compressed => {
        return call(UserWallet, 'deployBlob', {
            repoName: CURRENT_REPO_NAME,
            commit: commitSha,
            branch,
            blobName: `${type} ${sha}`,
            fullBlob: compressed,
            ipfsBlob: '',
            prevSha,
        })
    })
}

async function getBlobAddr(sha, type) {
    const repoContract = await getRepo()
    const result = await runLocal(repoContract, 'getBlobAddr', { nameBlob: `${type} ${sha}` }).catch(e => fatal(e.message))
    return result.decoded.output.value0
}

async function listBlobs(commitAddr) {
    const commitContract = { ...Commit, address: commitAddr }
    const result = await runLocal(commitContract, 'getBlobs')
    return result.decoded.output
}

// Blob contract
async function getBlob(sha, type) {
    const blobAddr = await getBlobAddr(sha, type).catch(e => fatal(e.message))
    const blobContract = { ...Blob, address: blobAddr }
    const result = await runLocal(blobContract, 'getBlob')
        .then(({ decoded }) => decoded.output)
        .catch(e => fatal(e.message))
    result.content = await decompress(result.content)
    return result
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

function compress(data) {
    return ES_CLIENT.utils.compress_zstd({
        uncompressed: Buffer.from(data).toString('base64'),
        level: 3
    }).then(({ compressed }) => compressed)
}

function decompress(data) {
    return ES_CLIENT.utils.decompress_zstd({
        compressed: data
    }).then(({ decompressed }) => Buffer.from(decompressed, 'base64').toString())
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
    getBranch,
    getRemoteHead,
    createCommit,
    getCommitAddr,
    getCommitByAddr,
    getCommit,
    setCommit,
    createBlob,
    getBlobAddr,
    listBlobs,
    getBlob,
    compress,
    decompress,
    // global vars
    goshContract,
    currentRepo,
    userWallet,
    ZERO_ADDRESS,
}
