import { TonClient } from "@eversdk/core";
import { toast } from "react-toastify";
import { SHA1 } from "crypto-js";
import { Buffer } from "buffer";
import { GoshDaoCreator } from "../types/classes";
import { IGoshDaoCreator, IGoshRepository, TDiffData, TGoshBranch } from "../types/types";


export const getEndpoints = (): string[] => {
    switch (process.env.REACT_APP_EVER_NETWORK) {
        case 'devnet':
            return ['https://net.ton.dev'];
        case 'mainnet':
            return ['https://main.ton.dev'];
        case 'se':
        default:
            return ['http://localhost'];
    }
}

export const getGoshDaoCreator = (client: TonClient): IGoshDaoCreator => {
    const address = process.env.REACT_APP_CREATOR_ADDR;
    if (!address) throw Error('No GoshDaoCreator address specified');
    return new GoshDaoCreator(client, address);
}

export const getGoshRepoBranches = async (
    repo: IGoshRepository,
    selectedBranchName: string = 'master'
): Promise<{ branchList: TGoshBranch[], branchCurr?: TGoshBranch }> => {
    const branches = await repo.getBranches();
    const branch = branches.find((branch) => branch.name === selectedBranchName);
    return { branchList: branches, branchCurr: branch };
}

/**
 * Generate commit diff content
 * @param monaco Monaco object from `useMonaco` hook
 */
export const generateDiff = async (
    monaco: any,
    modified: string,
    original?: string
): Promise<TDiffData[]> => {
    return new Promise((resolve, reject) => {
        if (!monaco) reject('Can not create diff (Diff editor is not initialized)');

        // Create hidden monaco diff editor and get diff
        const originalModel = monaco.editor.createModel(original, 'markdown');
        const modifiedModel = monaco.editor.createModel(modified, 'markdown');

        const diffContainer = document.createElement('div');
        const diffEditor = monaco.editor.createDiffEditor(diffContainer);
        diffEditor.setModel({ original: originalModel, modified: modifiedModel });
        diffEditor.onDidUpdateDiff(() => {
            const content = diffEditor.getOriginalEditor().getValue().split('\n');
            const changes = diffEditor.getLineChanges();
            const diff: TDiffData[] = [];
            changes.forEach((item: any) => {
                const {
                    originalStartLineNumber,
                    originalEndLineNumber,
                    modifiedStartLineNumber,
                    modifiedEndLineNumber
                } = item;

                const lines = [];
                for (let line = originalStartLineNumber - 1; line < originalEndLineNumber; line++) {
                    lines.push(content[line]);
                }
                diff.push({ modifiedStartLineNumber, modifiedEndLineNumber, originalLines: lines });
            });
            resolve(diff);
        });
    });
}

export const restoreFromDiff = (modified: string, diff: TDiffData[]): string => {
    const restored = [];
    const source = modified.split('\n');
    for (let mL = 0; mL < source.length; mL++) {
        const changed = diff.find((item) => item.modifiedStartLineNumber - 1 === mL);
        if (changed) {
            if (changed.modifiedEndLineNumber === 0) restored.push(source[mL]);
            restored.push(...changed.originalLines);
            if (changed.modifiedEndLineNumber > 0) mL = changed.modifiedEndLineNumber - 1;
        } else {
            restored.push(source[mL]);
        }
    }
    // console.log('Restored', restored);
    return restored.join('\n');
}

export const getCodeLanguageFromFilename = (monaco: any, filename: string): string => {
    let splitted = filename.split('.');
    const ext = `.${splitted[splitted.length - 1]}`;
    const found = monaco.languages.getLanguages().find((item: any) => (
        item.extensions.indexOf(ext) >= 0
    ));
    return found?.id || 'plaintext';
}

/**
 * Convert from nanoevers to evers
 * @param value
 * @param round
 * @returns
 */
export const toEvers = (value: any, round: number = 3): number => {
    const rounder = 10 ** round;
    return Math.round(value / 10 ** 9 * rounder) / rounder;
}

/**
 * Convert from evers to nanoevers
 * @param value
 * @returns
 */
export const fromEvers = (value: number): number => {
    return value * 10 ** 9;
}

export const sha1 = (data: string, type: 'blob' | 'commit'): string => {
    let content = data;
    if (type === 'commit') content += '\n';
    const size = Buffer.from(content, 'utf-8').byteLength;
    const object = `${type} ${size}\0${content}`;
    const hash = SHA1(object)
    return hash.toString();
}

/**
 * Toast shortcuts
 */
export const ToastOptionsShortcuts = {
    Default: {
        position: toast.POSITION.TOP_RIGHT,
        autoClose: 5000,
        hideProgressBar: false,
        closeOnClick: true,
        pauseOnHover: true,
        pauseOnFocusLoss: false,
        draggable: true,
        closeButton: true,
        progress: undefined
    },
    Message: {
        position: toast.POSITION.TOP_CENTER,
        autoClose: 1500,
        pauseOnFocusLoss: false,
        pauseOnHover: false,
        closeButton: false,
        hideProgressBar: true
    },
    CopyMessage: {
        position: toast.POSITION.TOP_CENTER,
        autoClose: 1500,
        pauseOnFocusLoss: false,
        pauseOnHover: false,
        closeButton: false,
        hideProgressBar: true,
        style: { width: '50%' },
        className: 'mx-auto'
    }
}

export const classNames = (...classes: any[]): string => classes.filter(Boolean).join(' ');

export const shortString = (data: string, start: number = 6, end: number = 6, delimiter: string = '...'): string => {
    if (data.length <= start + end) return data;

    const left = data.substring(0, start);
    const right = data.substring(data.length - end);
    return `${left}${delimiter}${right}`;
} 
