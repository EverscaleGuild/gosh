const { writeFileSync: writeFile } = require('fs')
const { verbose, execCmd, fatal, hexToUtf8, hexToAscii } = require('./utils')

const EMPTY_TREE_SHA = '4b825dc642cb6eb9a060e54bf8d69288fbee4904' // $ echo -n '' | git hash-object --stdin -t tree
const EMPTY_BLOB_SHA = 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391' // $ echo -n '' | git hash-object --stdin -t blob

const headCommit = () => execCmd('git rev-parse HEAD').then(([commit,]) => commit)
const headBranch = () => execCmd('git rev-parse --abbrev-ref HEAD').then(([short,]) => short)

function lsObjects(ref, exclude) {
    const excluded_refs = exclude ? exclude.map(i => `^${i}`).join(' ') : ''
    return execCmd(`git rev-list --objects --in-commit-order --reverse ${ref} ${excluded_refs}`)
}

function lsCommitedBlobNames(sha) {
    return execCmd(`git show --pretty= --name-only ${sha}`)
}

const lsTreeCommit = (sha) => execCmd(`git ls-tree -t -r --full-tree ${sha}`, true)

const catObject = (object, type) => {
    const argType = type ? `${type}` : '-p'
    return execCmd(`git cat-file ${argType} ${object}`, true)
}

const typeObject = (object) => execCmd(`git cat-file -t ${object}`).then(([type,]) => type)
const sizeObject = (object) => execCmd(`git cat-file -s ${object}`).then(([size,]) => size)

const blobPrevSha = (name) => execCmd(`git log --follow -p --oneline -n 1 $name | awk -F"[ .]" '/index.*100644/{print $2}`)

const isExistsObject = (object) =>
    execCmd(`git cat-file -e ${object}`).then(() => true).catch(() => false)

const extractRefs = (type, content) => {
    switch (type) {
        case 'blob':
            return []
        case 'tree':
            if (!content) return []
            return content.split('\n').reduce((list, line) => {
                const [mode, type, tail] = line.split(' ')
                return mode !== '160000' ? [...list, { type, sha: tail.split('\t')[0] }] : list
            }, [])
        case 'tag':
            tagSha = content.split('\n')[0].split(' ')[1]
            return [{ type: 'tag', sha: tagSha }]
        case 'commit':
            const list = []
            for (const line of content.split('\n')) {
                const [key, value] = line.split(' ', 2)
                if (key === 'parent') {
                    list.push({ type: 'commit', sha: value })
                } else if (key === 'tree') {
                    list.push({ type: 'tree', sha: value })
                } else {
                    break
                }
            }
            return list
    }
}

const getReferenced = (sha) => {
    const type = typeObject(sha)
    if (type === 'blob') return []
    const content = catObject(sha)
    return extractRefs(type, content)
}

const writeObject = async (type, content, options = {}) => {
    const { sha, dryRun = false } = options
    let input = `${content}\n`
    if (type === 'tree') {
        const entries = content.split('\n').map(entry => {
            const [mode,, tail] = entry.split(' ')
            const [sha, fn] = tail.split('\t')
            return Buffer.concat([
                Buffer.from(`${mode === '040000' ? '40000' : mode} ${fn}\0`),
                Buffer.from(sha, 'hex')
            ])
        })
        input = Buffer.concat(entries)
        // verbose('tree length:', input.length)
    }
    if (sha === 'd1105a6a48b55529a58049bf69733a1702b1b7b3') input = `${content}\n\n`
    const [computedSha,] = await execCmd(
        `git hash-object --stdin -t ${type} ${!dryRun ? '-w': ''}`,
        null,
        { input }
    )
    if (sha && computedSha != sha) fatal(`hash mismatched: (${computedSha}, ${sha}})`)
    return computedSha
}

/*
$ git show-ref
b255a682bed7a13da76900c0170932898160a903 refs/heads/master <- local master
e2ab2a79e246b554c938c5b98f4073002610ab2a refs/remotes/origin/master <- last known remote master
*/
const showRef = () => execCmd('git show-ref')
const lsRemote = (src = '') => execCmd(`git ls-remote ${src}`)
const headRef = () => execCmd('git symbolic-ref HEAD')
const refLog = (branch = '') => execCmd(`git reflog show ${branch}`)
const lsTree = (branch = 'master', path = '.') => execCmd(`git ls-tree ${branch} ${path}`)
const updateHeadRef = (head, commit) => execCmd(`git update-ref refs/heads/${head} ${commit}`)

const createBlob = (content) => execCmd()

module.exports = {
    EMPTY_TREE_SHA,
    EMPTY_BLOB_SHA,
    headBranch,
    headCommit,
    lsObjects,
    lsCommitedBlobNames,
    lsTreeCommit,
    catObject,
    typeObject,
    sizeObject,
    isExistsObject,
    extractRefs,
    getReferenced,
    writeObject,
}
