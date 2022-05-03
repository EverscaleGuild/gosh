import { create } from 'ipfs-core'

var ipfs_client = null

// singletone
function getIpfs() {
    if (ipfs_client !== null) {
        return ipfs_client
    }
    ipfs = create()
}

export async function saveToIPFS(path, content) {
    client = getIpfs()
    // TODO:
    // const cid = ...
    // return cid;
    throw new Error("Save for large files is not implemented yet.");
}

export async function loadFromIPFS(cid) {
    client = getIpfs()
    // TODO:
    // const content = ...
    // return content;
    throw new Error("Load for large files is not implemented yet.");
}
