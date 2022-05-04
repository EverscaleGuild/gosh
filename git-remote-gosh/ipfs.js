const all = require('it-all')
const ipfs = require('ipfs-core')
const Protector = require('libp2p/src/pnet')
const { exit } = require('process')
const { setTimeout } = require('timers/promises')


const SWARM_KEY = `/key/swarm/psk/1.0.0/
/base16/
0aa5e0806b7a6abf19f6e63689d3e6434df132571539b4ca7e5a1cbf4e3f8583`

const BOOTSTRAP_SERVERS = [
    "/ip4/51.91.62.120/tcp/4001/p2p/12D3KooWBjVe3SJcuHTdvZsSxPfAWfTSPHhqRP1GR7iqFiN9QcqY",
    "/ip4/51.210.114.148/tcp/4001/p2p/12D3KooWHoVMvnDm8hxGGiZdFH1WEkuaF3YxyF1A5JyifdYKi4Aq",
]

const PIN_REMOTE_ENDPOINT = 'http://test01.devops.services.tonlabs.io:9097/pins'

const PIN_QUEUE = {
    pins: [],
    cid_map: {},
}

let ipfs_node = undefined

// ~ UPDATE_INTERVAL * MAX_NETWORK_ERRORS seconds of doing nothing
const UPDATE_INTERVAL = 500 // ms
const MAX_NETWORK_ERRORS = 30
let networkErrors = 0

/**
 * Pin remote CID
 * !! Very unreliable method so we do many retries
 * @example
 *      curl -X POST -H "Content-Type: application/json" \
 *        -d '{"cid": "QmUtV6dzFDS6JNkj2e2dp5vxQPogdF58zQYwRL5v1LGEQe"}' \
 *        http://test01.devops.services.tonlabs.io:9097/pins
 * @param {String} cid 
 * @link https://ipfs.github.io/pinning-services-api-spec/#tag/pins/paths/~1pins~1{requestid}/get
 */
async function pinRemoteAdd(cid) {
    let response
    while (networkErrors < MAX_NETWORK_ERRORS) {
        response = await fetch(PIN_REMOTE_ENDPOINT, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ cid: cid.toString() }),
        })
        if (response.ok) break

        if (++networkErrors > MAX_NETWORK_ERRORS) {
            throw Error(`Fetch error: ${await response.join()}`)
        }
        await setTimeout(UPDATE_INTERVAL)
    }

    let pinStatus

    while(networkErrors < MAX_NETWORK_ERRORS) {
        if (response.ok) {
            pinStatus = await response.json()
            if (pinStatus.status == "pinned") {
                console.log(`CID ${cid} pinned`)
                return true
            }
        }

        if (++networkErrors > MAX_NETWORK_ERRORS) {
            throw Error(`Fetch error: ${await response.join()}`)
        }
        
        // next request
        await setTimeout(UPDATE_INTERVAL)
        response = await fetch(`${PIN_REMOTE_ENDPOINT}/${cid}`)
    }
}

const getIpfs = (() => {
    const config = {
        libp2p: {
            modules: {
                connProtector: new Protector(Buffer.from(SWARM_KEY))
            }
        },
        config: {
            Bootstrap: BOOTSTRAP_SERVERS,
            Addresses: { Swarm: [] }
        },
    }

    return async () => {
        return (ipfs_node ??= await ipfs.create(config))
    }
})()

/**
* @param {Buffer | String} content 
*/
async function saveToIPFS(content) {
    const ipfs = await getIpfs()
    // sem 1
    const { cid } = await ipfs.add(content)
    console.log(`cid = ${cid}`)
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

// async function main() {
//     let cids = await Promise.all([
//         saveToIPFS('test p2p 3'),
//         saveToIPFS('test p2p 4'),
//         saveToIPFS('test p2p 5'),
//         saveToIPFS('test p2p 6'),
//     ])

//     // console.log(await node.get())
//     // cid = "QmWmPp44STzyJifRBEiTSR3nWuy9FmaCjWSu4nbLnTWXWZ" // private bla
//     // cid = "QmZbj5ruYneZb8FuR9wnLqJCpCXMQudhSdWhdhp5U1oPWJ"
//     // cid = "QmVXKsmRf37NXa7fUN2BEqwh48nKTVFqkAeLzcrMWmYHHE"
//     // cid = "QmZULkCELmmk5XNfCgTnCyFgAVxBRBXyDHGGMVoLFLiXEN"
//     // cid = "QmVFRQABYYHeb84q7WiscT1QRMJvp7vwEjgN3CLj8BH39Y"

//     // const data = await loadFromIPFS(cid)
//     // console.log(data.toString())
// }

// ; (async () => { await main(); })()

module.exports = {
    loadFromIPFS,
    saveToIPFS,
}
