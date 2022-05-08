//@ts-check
const { verbose } = require('./utils')
const fetch = require('node-fetch')
const FormData = require('form-data')


const IPFS_HTTP_ENDPOINT = 'https://ipfs.network.gosh.sh'

/**
 * @link https://docs.ipfs.io/reference/http/api/#api-v0-add
 * @param {Buffer | String} content 
 * @param {String} filename
 * @returns {Promise<CID>}
 */
async function saveToIPFS(content, filename = undefined) {
    const form = new FormData()
    form.append('file', content, filename)

    const response = await fetch(`${IPFS_HTTP_ENDPOINT}/api/v0/add?pin=true&quiet=true`, {
        method: 'POST',
        body: form,
    })

    verbose(response.ok, response.status, response.statusText)
    if (!response.ok) {
        throw new Error('Error while uploading')
    }

    const responseBody = await response.json()
    verbose(responseBody)
    const { Hash: cid } = responseBody
    return cid
}

/**
 * @param {CID | string} cid 
 * @returns {Promise<Buffer>}
 */
async function loadFromIPFS(cid) {
    const response = await fetch(`${IPFS_HTTP_ENDPOINT}/ipfs/${cid.toString()}`, {
        method: 'GET',
    })
    if (!response.ok) {
        throw new Error('Error while uploading')
    }
    return Buffer.from(await response.arrayBuffer())
}

module.exports = {
    saveToIPFS,
    loadFromIPFS,
}

/**
 * @typedef {import('ipfs-core').CID} CID
 * @typedef {import('ipfs-core').Options} Options
 * @typedef {import('ipfs-core').IPFS} IPFS
 * @typedef {import('ipfs-utils/src/http').ExtendedResponse} ExtendedResponse
 */
