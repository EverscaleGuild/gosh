const { promises: fs } = require('fs')
const { join: pathJoin } = require('path')
const { createHash } = require('crypto')

const { TonClient } = require('@eversdk/core')
const { libNode } = require("@eversdk/lib-node")
const { saveToIPFS, loadFromIPFS } = require('./ipfs-http')
TonClient.useBinaryLibrary(libNode)

const { openRepo, blobPrevSha } = require('./git')
const { verbose, fatal } = require('./utils')
const pathGoshArtifacts = '../gosh'
const signerNone = { type: 'None' }
const ZERO_ADDRESS = '0:0000000000000000000000000000000000000000000000000000000000000000'
const ZERO_COMMIT = '0000000000000000000000000000000000000000'
const FEE_SET_COMMIT = 3e8

let ES_CLIENT
let CURRENT_DAO
let CURRENT_REPO_NAME
let CURRENT_REPO
let Gosh, Repository, Commit, Blob, Dao, Tag
let UserWallet = {}
let messageSeqNum = 0
let runLocalCounter = 0

const MAX_ONCHAIN_FILE_SIZE = 15360;


async function init(network, repo, goshAddress, credentials = {}) {
    const isHttp = process.env.GOSH_PROTO && process.env.GOSH_PROTO.toLowerCase().startsWith('http')
    console.error('PROTO:', isHttp ? 'HTTP' : 'WS')
    const config = {
        network: {
            endpoints: [network || 'network.gosh.sh'],
            queries_protocol: isHttp ? 'HTTP' : 'WS',
            message_retries_count: 10,
            message_processing_timeout: 220000000,
            wait_for_timeout: 220000000,
            query_timeout: 220000000,
        },
        defaultWorkchain: 0,
        log_verbose: false,
        abi: {
            message_expiration_timeout: 220000000
        }
    }

    ES_CLIENT = new TonClient(config)
    GOSH_ADDR = goshAddress

    const [dao, ...tail] = repo.split('/')
    if (!tail) fatal(`Incorrect repo name: ${repo}. DAO not found`)
    CURRENT_DAO = dao
    CURRENT_REPO_NAME = tail.join('/')
    await openRepo()

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
    const header = { time: ++messageSeqNum }
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
                header,
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

async function getContractStatus(address) {
    const query = {
        collection: 'accounts',
        filter: { id: { eq: address } },
        result: 'acc_type balance',
    }
    const { result } = await ES_CLIENT.net.query_collection(query)

    return result.length
        ? { status: result[0].acc_type, balance: +result[0].balance }
        : {}
}

async function checkExistence(sha, type) {
    try {
        verbose(`checkExistence(${sha}, ${type})`)
        let contract
        let result = false
        if (type === 'commit') {
            const address = await getCommitAddr(sha)
            contract = { ...Commit, address }
            const { status } = await getContractStatus(address)
            return status === 1
        } else if (type === 'tree' || type === 'blob') {
            const address = await getBlobAddr(sha, type)
            contract = { ...Blob, address }
            const { status } = await getContractStatus(address)
            return status === 1
        } else if (type === 'tag') {
            contract = Tag
        } else {
            verbose(`Unsupported type: ${type} (sha: ${sha})`)
        }
    } catch (err) {
        verbose('ERROR:', err.message)
        fatal('Oops!')
    }
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
    verbose('REPO:', result.decoded.output.value0)
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
        return result.filter(v => v.sha !== ZERO_COMMIT).map((v, i) => ({
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
            promises.push(getCommitAddr(value))
        }
    }
    if (promises.length === 0) promises.push(getCommitAddr(ZERO_COMMIT))
    const parents = await Promise.all(promises)
    return call(UserWallet, 'deployCommit', {
        repoName: CURRENT_REPO_NAME,
        branchName: branch,
        commitName: sha,
        fullCommit: content,
        parents,
    })
}

async function getCommitAddr(sha) {
    const repoContract = await getRepo(CURRENT_REPO_NAME)
    const result = await runLocal(repoContract, 'getCommitAddr', { nameCommit: sha }).catch(err => fatal(err))
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

async function getCommit(sha) {
    const commitAddr = await getCommitAddr(sha)
    return { type: 'commit', address: commitAddr, ...(await getCommitByAddr(commitAddr)) }
}

async function setCommit(branch, branchCommit, commit) {
    return call(UserWallet, 'setCommit', {
        repoName: CURRENT_REPO_NAME,
        branchName: branch,
        branchcommit: branchCommit === ZERO_ADDRESS ? await getCommitAddr(ZERO_COMMIT) : branchCommit,
        commit,
    })
}

async function createBlob(sha, type, size, binary, commitSha, filename, branch, content) {
    const prevSha = type === 'blob' && filename
        ? await blobPrevSha(filename, commitSha)
        : ''
    /* const diffContent = prevSha
        ? await git.diff(prevSha, sha)
        : content
    verbose(diffContent) */
    // TODO: wrap and push to queue
    const data = binary ? content.toString('base64') : content
    /* if (binary) {
        verbose(`[[[${content.toString('hex').replace(/(.)(.)/g, '$1$2 ')}]]]`)
    } */
    return compress(data).then(async (compressed) => {
        if (compressed.length > MAX_ONCHAIN_FILE_SIZE) {
            const ipfsCID = await saveToIPFS(compressed);
            return call(UserWallet, 'deployBlob', {
                repoName: CURRENT_REPO_NAME,
                commit: commitSha,
                branch,
                blobName: `${type} ${sha}`,
                fullBlob: '',
                ipfsBlob: ipfsCID,
                prevSha,
                flags: 0,
            })
        } else {
            return call(UserWallet, 'deployBlob', {
                repoName: CURRENT_REPO_NAME,
                commit: commitSha,
                branch,
                blobName: `${type} ${sha}`,
                fullBlob: compressed,
                ipfsBlob: '',
                prevSha,
                flags: 0,
            })
        }
    })
}

async function getBlobAddr(sha, type) {
    const repoContract = await getRepo()
    const result = await runLocal(repoContract, 'getBlobAddr', { nameBlob: `${type} ${sha}` }).catch(e => fatal(e.message))
    return result.decoded.output.value0
}

async function setBlobs(commit, blobs) {
    return call(UserWallet, 'setBlob', { repoName: CURRENT_REPO_NAME, commitName: commit, blobs })
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
    const { ipfs, ...blob } = await runLocal(blobContract, 'getBlob')
        .then(({ decoded }) => decoded.output)
        .catch(e => fatal(e.message))
    if (ipfs) verbose('cid:', ipfs, '| content:', !blob.content)
    if (!!ipfs && !blob.content) {
        verbose('ipfs: blob addr:', blobAddr)
        blob.content = await loadFromIPFS(ipfs)
        verbose('ipfs: got blob with size', blob.content.length)
    }
    blob.content = await decompress(blob.content)
    // dirty check if content is base64
    if (blob.content.slice(0, 5) === 'te6cc') {
        blob.content = Buffer.from(blob.content, 'base64')
    }
    return blob
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
    const compressed = Buffer.isBuffer(data) ? data.toString(/* 'base64' */) : data

    return ES_CLIENT.utils.decompress_zstd({ compressed })
        .then(({ decompressed }) => Buffer.from(decompressed, 'base64').toString())
        .catch(fatal)
}

// global vars wrappers
const goshContract = () => Gosh
const currentRepo = () => CURRENT_REPO_NAME
const userWallet = () => UserWallet

module.exports = {
    init,
    checkExistence,
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
    setBlobs,
    listBlobs,
    getBlob,
    compress,
    decompress,
    // global vars
    goshContract,
    currentRepo,
    userWallet,
    ZERO_ADDRESS,
    MAX_ONCHAIN_FILE_SIZE,
}
