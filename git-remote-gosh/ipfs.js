const all = require('it-all')
const ipfs = require('ipfs-core')
const Protector = require('libp2p/src/pnet')
const { exit } = require('process')


const SWARM_KEY = `/key/swarm/psk/1.0.0/
/base16/
0aa5e0806b7a6abf19f6e63689d3e6434df132571539b4ca7e5a1cbf4e3f8583`

const BOOTSTRAP_SERVERS = [
    "/ip4/51.91.62.120/tcp/4001/p2p/12D3KooWBjVe3SJcuHTdvZsSxPfAWfTSPHhqRP1GR7iqFiN9QcqY",
    "/ip4/51.210.114.148/tcp/4001/p2p/12D3KooWHoVMvnDm8hxGGiZdFH1WEkuaF3YxyF1A5JyifdYKi4Aq",
]

const PIN_REMOTE_ENDPOINT = 'http://test01.devops.services.tonlabs.io:9097/pins'


//     curl -X POST -H "Content-Type: application/json" \
//    -d '{"cid": "QmUtV6dzFDS6JNkj2e2dp5vxQPogdF58zQYwRL5v1LGEQe"}' \
//    http://test01.devops.services.tonlabs.io:9097/pins
async function pinRemoteAdd(cid) {
    const request = fetch(PIN_REMOTE_ENDPOINT, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({cid: cid.toString()}),
    })
    const response = await request
    console.log(response.status)
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
    const _getIpfs = (async function* () {
        const node = await ipfs.create(config)
        while (true) {
            yield node
        }
    })()

    return async () => {
        return (await _getIpfs.next()).value
    }
})()

/**
 * @param {Buffer | String} content 
 */
async function saveToIPFS(content) {
    const ipfs = await getIpfs()
    res = await ipfs.add(content)
    const { cid } = res
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

async function main() {
    let cid = await saveToIPFS('test p2p 6')
    console.log(`cid = ${cid}`)

    // console.log(await node.get())
    // cid = "QmWmPp44STzyJifRBEiTSR3nWuy9FmaCjWSu4nbLnTWXWZ" // private bla
    // cid = "QmZbj5ruYneZb8FuR9wnLqJCpCXMQudhSdWhdhp5U1oPWJ"
    // cid = "QmVXKsmRf37NXa7fUN2BEqwh48nKTVFqkAeLzcrMWmYHHE"
    // cid = "QmZULkCELmmk5XNfCgTnCyFgAVxBRBXyDHGGMVoLFLiXEN"
    // cid = "QmVFRQABYYHeb84q7WiscT1QRMJvp7vwEjgN3CLj8BH39Y"

    // const data = await loadFromIPFS(cid)
    // console.log(data.toString())
    setTimeout(() => {
        exit()
    }, 30)
}

; (async () => { await main(); })()

module.exports = {
    loadFromIPFS,
    saveToIPFS,
}
