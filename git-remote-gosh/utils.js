const { Buffer } = require('buffer')
const { spawn, execSync: exec } = require('child_process')
const zlib = require('zlib')

const convert = (from, to) => data => Buffer.from(data, from).toString(to)

const hexToAscii = convert('hex', 'ascii')
const hexToUtf8 = convert('hex', 'utf8')
const utf8ToHex = convert('utf8', 'hex')

const verbose = (...data) => console.error(...data)

const fatal = (...data) => {
    verbose(...data)
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
    // repo url -> gosh::<network>://<account>@<repository>
    //     gosh - protocol scheme (fixed)
    //     network - main (by default), dev, localnode etc
    //     account - ref to credentials (~/.gosh/credentials.json)
    //     repository - name of the remote repository
    const [head, tail] = url.split('://')
    if (!tail) {
        fatal(MALFORMED_ERR)
    }
    let [scheme, network] = head.split('::')
    if (!network) {
        network = scheme
        scheme = 'gosh'
    }
    let [account, repo] = tail.split('@')
    if (!repo) {
        repo = account
        account = undefined
    }
    if (!scheme && !repo) {
        fatal(MALFORMED_ERR)
    }
    return {
        scheme,
        ...(network && { network }),
        account: account || 'default',
        repo,
    }
}

/* function execCmd(cmd, raw = false, options = {}) {
    verbose(`debug: shell$ ${cmd}`)
    const [command, ...args] = cmd.trimEnd().split(' ')

    return new Promise((resolve, reject) => {
        const subprocess = spawn(command, args, { stdio: [null, null, null] })
        verbose('debug: spawned subprocess')
        const output = []
        
        subprocess.stdout.on('data', (data) => {
            process.stderr.write(`child stdout: ${data}`)
            output.push(...data.toString('utf-8').trimEnd().split('\n'))
        })

        subprocess.stderr.on('data', (data) => {
            process.stderr.write(`child stderr: ${data}`)
        })

        subprocess.on('error', (err) => {
            process.stderr.write(`error: failed to run subrocess "${cmd} ${JSON.stringify(args)}"`)
            reject(err)
        })

        subprocess.on('close', (code) => {
            process.stderr.write(`child: process exited with code ${code}\n`)
            resolve(output)
        })
    })
} */

const execCmd = (cmd, raw = false, options = {}) => {
    // verbose(`debug: shell$ ${cmd}`)
    // if (options.input) verbose(`\twith piped: ${options.input}`)

    const out = exec(cmd, options).toString('utf-8').trimEnd()
    return raw ? out : out.split('\n')
}

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
    verbose,
    fatal,
    emoji_shrug,
    send,
    deconstructRemoteUrl,
    execCmd,
    deflate,
    inflate,
}