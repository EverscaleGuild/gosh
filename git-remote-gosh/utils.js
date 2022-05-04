const { Buffer } = require('buffer')
const { spawn } = require('child_process')
const zlib = require('zlib')

const bufLF = Buffer.from([0x0a])

let _verbosity = false
let _progress = false
let _dryRun = false

const convert = (from, to) => data => Buffer.from(data, from).toString(to)

const hexToAscii = convert('hex', 'ascii')
const hexToUtf8 = convert('hex', 'utf8')
const utf8ToHex = convert('utf8', 'hex')

function setVerboseFlag(flag) {
    _verbosity = Boolean(flag > 1)
}

function setProgressFlag(flag) {
    _progress = Boolean(flag)
}

function setDryRunFlag(flag) {
    _dryRun = Boolean(flag)
}

const getProgressFlag = () => _progress
const getDryRunFlag = () => _dryRun

const verbose = (...data) => {
    if (_verbosity) {
        console.error('debug:', ...data)
    }
}

const fatal = (...data) => {
    console.error('error:', ...data)
    process.exit(1)
}

const send = (data) => {
    if (data) {
        verbose(`< ${data}`)
        process.stdout.write(`${data}\n`)
    } else {
        verbose('<')
        process.stdout.write('\n')
    }
}

const emoji_shrug = "¯\\_(ツ)_/¯"

const deconstructRemoteUrl = (url) => {
    const MALFORMED_ERR = `The following URL is malformed: ${url}. A URL must be in the two following format: gosh::<network>://<account>@<repository>`
    // repo url -> gosh::<network>://<account>@<contract>/<repository>
    //     gosh - protocol scheme (fixed)
    //     network - main (by default), dev, localnode etc
    //     account - ref to credentials (~/.gosh/credentials.json)
    //     contract - Gosh root contract address
    //     repository - name of the remote repository
    const [head, tail] = url.split('://')
    if (!tail) fatal(MALFORMED_ERR)

    let [scheme, network] = head.split('::')
    if (!scheme) fatal(MALFORMED_ERR)
    if (!network) {
        if (scheme !== 'gosh') {
            network = scheme
            scheme = 'gosh'
        }
    }
    let [account, path] = tail.split('@')
    if (!path) {
        path = account
        account = undefined
    }
    let [gosh, ...repo] = path.split('/')
    repo = repo.join('/')
    if (!(scheme || gosh || repo)) {
        fatal(MALFORMED_ERR)
    }
    return {
        scheme,
        network,
        account: account || 'default',
        repo,
        gosh,
    }
}

function execCmd(cmd, raw = false, options = {}) {
    verbose(`shell$ ${cmd}`)
    const [command, ...args] = cmd.trimEnd().split(' ')

    return new Promise((resolve, reject) => {
        const subprocess = spawn(command, args, { shell: true })
        if (options.input) {
            subprocess.stdin.write(options.input)
            subprocess.stdin.end()
        }
        const output = []
        
        subprocess.stdout.on('data', (data) => {
            output.push(data)
        })

        subprocess.stderr.on('data', (data) => {
            verbose(`child stderr: ${data}`)
        })

        subprocess.on('error', (err) => {
            verbose(`error: failed to run subrocess "${cmd} ${JSON.stringify(args)}"`)
            reject(err)
        })

        subprocess.on('close', (code) => {
            if (code === 0) {
                if (output.length === 0) return resolve('')

                const lastChar = output.at(-1).slice(-1)
                if (lastChar.equals(bufLF)) output[output.length - 1] = output[output.length - 1].slice(0, -1)
                const result = Buffer.concat(output).toString('utf-8')
                resolve(raw ? result : result.split('\n'))
            } else {
                reject(new Error(`child: process exited with code ${code}`))
            }
        })
    })
}

/* const execCmd = (cmd, raw = false, options = {}) => {
    // verbose(`debug: shell$ ${cmd}`)
    // if (options.input) verbose(`\twith piped: ${options.input}`)

    const out = exec(cmd, options).toString('utf-8').trimEnd()
    return raw ? out : out.split('\n')
} */

const deflate = (data) => {
    const input = Buffer.from(data, 'utf8')

    return new Promise((resolve, reject) => {
        zlib.deflate(input, (err, buf) => {
            if (err) return reject(err.message)
            verbose('deflate:', buf.toString('base64'))
            resolve(buf.toString('base64'))
        })
    })
}

const inflate = async (data) => {
    const input = Buffer.from(data, 'base64')

    return new Promise((resolve, reject) => {
        zlib.inflate(input, (err, buf) => {
            if (err) return reject(err.message)
            resolve(buf.toString('utf-8'))
        })
    })
}

module.exports = {
    hexToAscii,
    hexToUtf8,
    utf8ToHex,
    setVerboseFlag,
    setProgressFlag,
    setDryRunFlag,
    getProgressFlag,
    getDryRunFlag,
    verbose,
    fatal,
    emoji_shrug,
    send,
    deconstructRemoteUrl,
    execCmd,
    deflate,
    inflate,
}