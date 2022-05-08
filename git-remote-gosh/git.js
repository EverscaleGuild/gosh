const { assert } = require('console')
const Git = require('nodegit')
const { verbose, execCmd, fatal } = require('./utils')

const EMPTY_TREE_SHA = '4b825dc642cb6eb9a060e54bf8d69288fbee4904' // $ echo -n '' | git hash-object --stdin -t tree
const EMPTY_BLOB_SHA = 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391' // $ echo -n '' | git hash-object --stdin -t blob
const FILEMODE = {
    16384: '040000',
    33188: '100644',
    33261: '100755',
}

let REPO

const openRepo = () => {
    if (REPO) return Promise.resolve(REPO)

    return Git.Repository.openExt('.', 0, '')
        .then(repo => {
            REPO = repo
            return REPO
        }).catch(err => {
            verbose(err.message)
            return null
        })
}

const headCommit = () => execCmd('git rev-parse HEAD').then(([commit,]) => commit)
const headBranch = () => execCmd('git rev-parse --abbrev-ref HEAD').then(([short,]) => short)

function lsObjects(ref, exclude) {
    const excluded_refs = exclude ? exclude.map(i => `^${i}`).join(' ') : ''
    return execCmd(`git rev-list --objects --in-commit-order --reverse ${ref} ${excluded_refs}`)
}

const lsCommitedBlobNames = (sha) => execCmd(`git show --pretty= --name-only ${sha}`)

const lsTreeCommit = (sha) => execCmd(`git ls-tree -t -r --full-tree ${sha}`, true)

const catObject = (object, type) => {
    const argType = type ? `${type}` : '-p'
    return execCmd(`git cat-file ${argType} ${object}`, true)
}

const typeObject = (object) => execCmd(`git cat-file -t ${object}`).then(([type,]) => type)
const sizeObject = (object) => execCmd(`git cat-file -s ${object}`).then(([size,]) => size)

const objectData = (object) => {
    return Promise.all([
        typeObject(object),
        // sizeObject(object),
        catObject(object),
    ]).then(([type, /* size,  */content]) => ({ type, /* size,  */content }))
}

const objectData2 = (object) => {
    return execCmd('git cat-file --batch', true, { input: object })
        .then(output => {
            const notch = output.indexOf('\n')
            const [sha, type, size] = output.slice(0, notch).split(' ')
            const content = output.slice(notch + 1)
            verbose(size, content.length)
            assert(size == content.length)
            return { sha, type, size, content }
        })
}

const objectData3 = async (sha) => {
    let data
    const object = await Git.Object.lookup(REPO, sha, Git.Object.TYPE.ANY)
    const type = object.type()
    if (type === Git.Object.TYPE.BLOB) {
        const blob = await Git.Blob.lookup(REPO, object.id())
        data = {
            type: 'blob',
            size: blob.rawsize(),
            content: blob.content(),
            binary: Boolean(blob.isBinary())
        }
    } else if (type === Git.Object.TYPE.TREE) {
        const tree = await Git.Tree.lookup(REPO, object.id())
        const content = tree
            .entries()
            .map(ent => `${FILEMODE[ent.filemodeRaw()]} ${Git.Object.type2String(ent.type())} ${ent.sha()}\t${ent.path()}`)
            .join('\n')
        data = { type: 'tree', content }
    } else if (type === Git.Object.TYPE.COMMIT) {
        const commit = await Git.Commit.lookup(REPO, object.id())
        data = {
            type: 'commit',
            content: `${commit.rawHeader()}\n${commit.message()}`
        }
    } else if (type === Git.Object.TYPE.TAG) {

    } else {
        fatal(`Unsupported type: ${type} (${sha})`)
    }
    return data
}

const revparse = (ref) => {
    return Git.Revparse.single(REPO, ref).then(obj => obj.id().tostrS())
}

const blobPrevSha = (name, commit) =>
    execCmd(`git log --follow -p --oneline -n 1 ${commit} -- ${name} | awk -F"[ .]" '/^index.*/{print ($2==0000000)? \"\" : $2}'`)
        .then(({ 0: sha }) => {
            return sha ? revparse(sha) : ''
        })

const diff = (aSha, bSha) => execCmd(`git diff --no-color ${aSha} ${bSha} | sed 1,1d`, true)

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
    let input = content
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
    const [computedSha,] = await execCmd(
        `git hash-object --stdin -t ${type} ${!dryRun ? '-w': ''}`,
        null,
        { input }
    )
    if (sha && computedSha != sha) {
        verbose('bad content size:', content.length)
        /* if (Buffer.isBuffer(content)) {
            verbose(`[[[${content.toString('hex').replace(/(.)(.)/g, '$1$2 ')}]]]`)
        } else {
            verbose(`[[[${content}]]]`)
        } */
        fatal(`hash mismatched: (${computedSha}, ${sha}})`)
    }
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
    openRepo,
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
    objectData,
    objectData2,
    objectData3,
    revparse,
    blobPrevSha,
    diff,
    isExistsObject,
    extractRefs,
    getReferenced,
    writeObject,
}
