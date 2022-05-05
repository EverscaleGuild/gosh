//@ts-check
const all = require('it-all')
const ipfs = require('ipfs-core')
const Protector = require('libp2p/src/pnet')
const { setTimeout } = require('timers/promises')
const { BetterLock } = require('better-lock');
const { verbose } = require('./utils')
const HTTP = require('ipfs-utils/src/http')


const SWARM_KEY = `/key/swarm/psk/1.0.0/
/base16/
0aa5e0806b7a6abf19f6e63689d3e6434df132571539b4ca7e5a1cbf4e3f8583`

const BOOTSTRAP_SERVERS = [
    "/dns4/n01.network.gosh.sh/tcp/4001/ipfs/12D3KooWKfrNXN3msmrd5SYP6yFmWypGf2aicxPzJ1v2RXiRVCDk",
    "/dns4/n02.network.gosh.sh/tcp/4001/ipfs/12D3KooWDvM2UE9ZsPQ9nC7QoVsrd9uVLuzNV2gBXa9zLpt67AHb",
    "/dns4/n03.network.gosh.sh/tcp/4001/ipfs/12D3KooWBvUFBdT1uYn8ftHjkKb193LRfndNXZejEyngQ2cHGfyF",
    "/dns4/n04.network.gosh.sh/tcp/4001/ipfs/12D3KooWA9CWkyYfv5kBcabYnKB5HH81WzcQ4uBjop9i6iPDbuYt",
    "/dns4/n05.network.gosh.sh/tcp/4001/ipfs/12D3KooWRXRmXrWmkDd3nzo3c25f9BifNf2qdJtBto6vn77jyveg",
    "/dns4/n06.network.gosh.sh/tcp/4001/ipfs/12D3KooWAYrCWysudygmwxKTjKxdBFCQdkP7d44Uh7xP9JgCteKb",
    "/dns4/n07.network.gosh.sh/tcp/4001/ipfs/12D3KooWRwHJUJ7ypnEJ8VYMCrBQXynsmwypD7yECfCguV5QVLV3",
    "/dns4/n08.network.gosh.sh/tcp/4001/ipfs/12D3KooWDdQq6ZkBspUFuCAFr2MAoTjhDfGyMtcqq9vXrgdHFGPC",
    "/dns4/n09.network.gosh.sh/tcp/4001/ipfs/12D3KooWQVLdvT351X3aPqLYH8C3FvHiE5AGsPRPncMJFVd26xiD",
]

const PIN_REMOTE_ENDPOINT = "http://pin.ipfs.gosh.sh:9097"
const PIN_BEARER_KEY = ""

const ipfs_lock = new BetterLock()
let ipfs_node = undefined

// ~ UPDATE_INTERVAL * MAX_NETWORK_ERRORS seconds of doing nothing
const UPDATE_INTERVAL = 1000 // ms
const MAX_NETWORK_ERRORS = 30
let networkErrors = 0

/** @type {HTTP} */
const PIN_API = new HTTP({
    base: PIN_REMOTE_ENDPOINT,
    headers: {
        Authorization: `Bearer ${PIN_BEARER_KEY}`,
        'Content-Type': 'application/json'
    }
})

/**
 * Pin remote CID
 * !! Very unreliable method so we do many retries
 * @example
 *      curl -X POST -H "Content-Type: application/json" \
 *        -d '{"cid": "QmUtV6dzFDS6JNkj2e2dp5vxQPogdF58zQYwRL5v1LGEQe"}' \
 *        http://pin.ipfs.gosh.sh:9097/pins
 * @param {CID | String} cid 
 * @link https://ipfs.github.io/pinning-services-api-spec/#tag/pins/paths/~1pins~1{requestid}/get
 */
async function pinRemoteAdd(cid) {
    /** @type {ExtendedResponse} */
    let response
    let responseBody
    while (networkErrors < MAX_NETWORK_ERRORS) {
        verbose(`${networkErrors} POST pin ${cid}`)
        response = await PIN_API.post('/pins', { json: { cid: cid.toString() } })
        responseBody = await response.json()
        if (response.ok) break

        if (++networkErrors > MAX_NETWORK_ERRORS) {
            throw new Error(`Fetch error: ${responseBody}`)
        }
        await setTimeout(UPDATE_INTERVAL)
    }

    while (networkErrors < MAX_NETWORK_ERRORS) {
        if (response.ok) {
            const { status } = responseBody
            if (status == "failed") {
                throw new Error(`Pinning ${cid} failed`)
            }
            if (status == "pinned") {
                verbose(`CID ${cid} pinned`)
                return true
            }
        }

        if (++networkErrors > MAX_NETWORK_ERRORS) {
            throw new Error(`Fetch error: ${await response.json()}`)
        }

        // next request
        verbose(`${networkErrors} SLEEP interval ${cid}`)
        await setTimeout(UPDATE_INTERVAL)
        verbose(`${networkErrors} GET pin ${cid}`)
        response = await PIN_API.get(`/pins/${cid}`)
        responseBody = await response.json()
        verbose(response.status, cid, responseBody)
    }
}

const getIpfs = (() => {
    /** @type {Options} */
    const config = {
        libp2p: {
            // @ts-ignore
            modules: {
                connProtector: new Protector(Buffer.from(SWARM_KEY))
            }
        },
        config: {
            Bootstrap: BOOTSTRAP_SERVERS,
            Addresses: { Swarm: [] },
        },
    }

    /**
     * @returns {Promise<IPFS>}
     */
    return async () => {
        // !! lock strongly required because somehow create tries to create new storage(or check if exists)
        // !! meanwhile other async thread tries to do the same
        return await ipfs_lock.acquire(async () => {
            return ipfs_node ??= await ipfs.create({
                ...config,
            })
        })
    }
})()

/**
* @param {Buffer | String} content 
* @returns {Promise<CID>}
*/
async function saveToIPFS(content) {
    const ipfs = await getIpfs()
    const { cid } = await ipfs.add(content)
    verbose(`\ncid = ${cid}\n`)
    await pinRemoteAdd(cid)
    return cid;
}

/**
* @param {CID | string} cid 
* @returns {Promise<Buffer>}
*/
async function loadFromIPFS(cid) {
    const ipfs = await getIpfs()
    const output = await all(ipfs.cat(cid))
    return Buffer.concat(output)
}

/// testing poligon

// async function main() {
//     verbose(`start poligon`)
//     let cids = await Promise.all([
//         saveToIPFS('test p2p _c1'),
//         saveToIPFS('test p2p _c2'),
//         saveToIPFS('test p2p _c3'),
//         saveToIPFS('test p2p _c4'),
//     ])


//     // const data = await loadFromIPFS(cid)
//     // verbose(data.toString())
//     const res = await Promise.all(cids.map((cid) => loadFromIPFS(cid)))
//     res.forEach((res) => verbose(`==\n${res}\n--`))
//     process.exit(0)
// }

// ; (async () => { await main(); })()

module.exports = {
    loadFromIPFS,
    saveToIPFS,
}

/**
 * @typedef {import('ipfs-core').CID} CID
 * @typedef {import('ipfs-core').Options} Options
 * @typedef {import('ipfs-core').IPFS} IPFS
 * @typedef {import('ipfs-utils/src/http').ExtendedResponse} ExtendedResponse
 */
