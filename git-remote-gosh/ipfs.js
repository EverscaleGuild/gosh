const all = require('it-all')
const ipfs = require('ipfs-core')
const Protector = require('libp2p/src/pnet')
const { setTimeout } = require('timers/promises')
const { BetterLock } = require('better-lock');
const { verbose } = require('./utils')


const SWARM_KEY = `/key/swarm/psk/1.0.0/
/base16/
0aa5e0806b7a6abf19f6e63689d3e6434df132571539b4ca7e5a1cbf4e3f8583`

const BOOTSTRAP_SERVERS = [
    "/ip4/51.91.62.120/tcp/4001/p2p/12D3KooWBjVe3SJcuHTdvZsSxPfAWfTSPHhqRP1GR7iqFiN9QcqY",
    "/ip4/51.210.114.148/tcp/4001/p2p/12D3KooWHoVMvnDm8hxGGiZdFH1WEkuaF3YxyF1A5JyifdYKi4Aq",
]

const PIN_REMOTE_ENDPOINT = "http://pin.ipfs.gosh.sh:9097/pins"


const ipfs_lock = new BetterLock()


let ipfs_node = undefined

// ~ UPDATE_INTERVAL * MAX_NETWORK_ERRORS seconds of doing nothing
const UPDATE_INTERVAL = 1000 // ms
const MAX_NETWORK_ERRORS = 30
let networkErrors = 0

/**
 * Pin remote CID
 * !! Very unreliable method so we do many retries
 * @example
 *      curl -X POST -H "Content-Type: application/json" \
 *        -d '{"cid": "QmUtV6dzFDS6JNkj2e2dp5vxQPogdF58zQYwRL5v1LGEQe"}' \
 *        http://pin.ipfs.gosh.sh:9097/pinss
 * @param {String} cid 
 * @link https://ipfs.github.io/pinning-services-api-spec/#tag/pins/paths/~1pins~1{requestid}/get
 */
async function pinRemoteAdd(cid) {
    let response
    while (networkErrors < MAX_NETWORK_ERRORS) {
        verbose(`${networkErrors} POST pin ${cid}`)
        response = await fetch(PIN_REMOTE_ENDPOINT, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ cid: cid.toString() }),
        })
        verbose(response.status, cid, PIN_REMOTE_ENDPOINT, await response.json())
        verbose(ipfs_node.isOnline())
        if (response.ok) break

        if (++networkErrors > MAX_NETWORK_ERRORS) {
            console.error(`Fetch error: ${await response.json()}`)
            process.exit(1)
        }
        await setTimeout(UPDATE_INTERVAL)
    }

    let pinStatus

    while (networkErrors < MAX_NETWORK_ERRORS) {
        if (response.ok) {
            pinStatus = await response.json()
            if (pinStatus.status == "pinned") {
                verbose(`CID ${cid} pinned`)
                return true
            }
        }

        if (++networkErrors > MAX_NETWORK_ERRORS) {
            console.error(`Fetch error: ${await response.json()}`)
            process.exit(1)
        }

        // next request
        verbose(`${networkErrors} SLEEP interval ${cid}`)
        await setTimeout(UPDATE_INTERVAL)
        verbose(`${networkErrors} GET pin ${cid}`)
        const url = `${PIN_REMOTE_ENDPOINT}/${cid}`
        response = await fetch(url)
        verbose(response.status, cid, url, await response.json())
    }
}
const getIpfs = (() => {
    /** @type {import('ipfs-core').Options} */
    const config = {
        libp2p: {
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
     * @returns {Promise<import('ipfs-core').IPFS>}
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
*/
async function saveToIPFS(content) {
    const ipfs = await getIpfs()
    const { cid } = await ipfs.add(content)
    verbose(`\ncid = ${cid}\n`)
    await pinRemoteAdd(cid)
    return cid;
}

/**
* @param {string} cid 
*/
async function loadFromIPFS(cid) {
    const ipfs = await getIpfs()
    const output = await all(ipfs.cat(cid))
    return Buffer.concat(output)
}

/// testing poligon

// async function main() {
//     let cids = await Promise.all([
//         saveToIPFS('test p2p _a1'),
//         saveToIPFS('test p2p _a2'),
//         saveToIPFS('test p2p _a3'),
//         saveToIPFS('test p2p _a4'),
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
