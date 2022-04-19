import { Account } from "@eversdk/appkit";
import { KeyPair, signerKeys, signerNone, TonClient } from "@eversdk/core";
import GoshDaoCreatorABI from "../contracts/daocreater.abi.json";
import GoshABI from "../contracts/gosh.abi.json";
import GoshDaoABI from "../contracts/goshdao.abi.json";
import GoshWalletABI from "../contracts/goshwallet.abi.json";
import GoshRepositoryABI from "../contracts/repository.abi.json";
import GoshSnapshotABI from "../contracts/snapshot.abi.json";
import GoshCommitABI from "../contracts/commit.abi.json";
import GoshBlobABI from "../contracts/blob.abi.json";
import { fromEvers, getGoshDaoCreator } from "../utils";
import {
    IGoshBlob,
    TGoshBranch,
    IGoshCommit,
    IGoshRepository,
    IGoshRoot,
    IGoshSnapshot,
    TDiffData,
    IGoshDao,
    IGoshWallet,
    IGoshDaoCreator
} from "./types";


export class GoshDaoCreator implements IGoshDaoCreator {
    abi: any = GoshDaoCreatorABI;
    account: Account;
    address: string;

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async createDao(name: string, rootPubkey: string): Promise<void> {
        await this.account.run('deployDao', { name, root_pubkey: rootPubkey });
    }

    async sendMoneyDao(name: string, value: number): Promise<void> {
        await this.account.run('sendMoneyDao', { name, value });
    }

    async sendMoney(rootPubkey: string, pubkey: string, daoAddr: string, value: number): Promise<void> {
        await this.account.run(
            'sendMoney',
            {
                pubkeyroot: rootPubkey,
                pubkey,
                goshdao: daoAddr,
                value
            }
        );
    }
}
export class GoshRoot implements IGoshRoot {
    abi: any = GoshABI;
    account: Account;
    address: string;
    daoCreator: IGoshDaoCreator;

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.daoCreator = getGoshDaoCreator(client);
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async createDao(name: string, rootPubkey: string): Promise<string> {
        await this.daoCreator.createDao(name, rootPubkey);
        return await this.getDaoAddr(name);
    }

    async getDaoAddr(name: string): Promise<string> {
        const result = await this.account.runLocal('getAddrDao', { name });
        return result.decoded?.output.value0;
    }

    async getDaoWalletCode(pubkey: string): Promise<string> {
        const result = await this.account.runLocal('getDaoWalletCode', { pubkey });
        return result.decoded?.output.value0;
    }

    async getRepoAddr(name: string, daoAddr: string): Promise<string> {
        const result = await this.account.runLocal(
            'getAddrRepository',
            { name, dao: daoAddr }
        );
        return result.decoded?.output.value0;
    }

    async getDaoRepoCode(daoAddress: string): Promise<string> {
        const result = await this.account.runLocal('getRepoDaoCode', { dao: daoAddress });
        return result.decoded?.output.value0;
    }
}

export class GoshDao implements IGoshDao {
    abi: any = GoshDaoABI;
    account: Account;
    address: string;
    daoCreator: IGoshDaoCreator;
    meta?: {
        name: string;
    };

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.daoCreator = getGoshDaoCreator(client);
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async load(): Promise<void> {
        this.meta = {
            name: await this.getName()
        }
    }

    async createWallet(rootPubkey: string, pubkey: string): Promise<string> {
        await this.account.run('deployWallet', { pubkeyroot: rootPubkey, pubkey });
        await this.daoCreator.sendMoney(rootPubkey, pubkey, this.address, fromEvers(100));
        return await this.getWalletAddr(rootPubkey, pubkey);
    }

    async getWalletAddr(rootPubkey: string, pubkey: string): Promise<string> {
        const result = await this.account.runLocal(
            'getAddrWallet',
            { pubkeyroot: rootPubkey, pubkey }
        );
        return result.decoded?.output.value0;
    }

    async getName(): Promise<string> {
        const result = await this.account.runLocal('getNameDao', {});
        return result.decoded?.output.value0;
    }

    async getRootPubkey(): Promise<string> {
        const result = await this.account.runLocal('getRootPubkey', {});
        return result.decoded?.output.value0;
    }
}

export class GoshWallet implements IGoshWallet {
    abi: any = GoshWalletABI;
    account: Account;
    address: string;

    constructor(client: TonClient, address: string, keys?: KeyPair) {
        this.address = address;
        this.account = new Account(
            { abi: this.abi },
            {
                client,
                address,
                signer: keys ? signerKeys(keys) : signerNone()
            }
        );
    }

    async getDaoAddr(): Promise<string> {
        const result = await this.account.runLocal('getAddrDao', {});
        return result.decoded?.output.value0;
    }

    async createRepo(name: string): Promise<void> {
        await this.account.run('deployRepository', { nameRepo: name });
    }

    async createBranch(
        repoName: string,
        newName: string,
        fromName: string,
        filesCount: number
    ): Promise<void> {
        await this.account.run(
            'deployBranch',
            { repoName, newName, fromName, amountFiles: filesCount }
        );
    }

    async deleteBranch(repoName: string, branchName: string): Promise<void> {
        await this.account.run('deleteBranch', { repoName, Name: branchName });
    }

    async createCommit(
        repoName: string,
        branchName: string,
        commitSha: string,
        commitData: string,
        parent1: string,
        parent2: string
    ): Promise<void> {
        await this.account.run(
            'deployCommit',
            {
                repoName,
                branchName,
                commitName: commitSha,
                fullCommit: commitData,
                parent1,
                parent2
            }
        );
    }

    async createBlob(
        repoName: string,
        commit: string,
        blobSha: string,
        blobContent: string
    ): Promise<void> {
        await this.account.run(
            'deployBlob',
            {
                repoName,
                commit,
                blobName: blobSha,
                fullBlob: blobContent
            }
        );
    }

    async createDiff(
        repoName: string,
        branchName: string,
        filePath: string,
        diff: string
    ): Promise<void> {
        await this.account.run(
            'deployDiff',
            {
                repoName,
                branch: branchName,
                name: filePath,
                diff
            }
        );
    }
}

export class GoshRepository implements IGoshRepository {
    abi: any = GoshRepositoryABI;
    account: Account;
    address: string;
    meta?: {
        name: string;
        branchCount: number;
    }

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async load(): Promise<void> {
        const branches = await this.getBranches();
        this.meta = {
            name: await this.getName(),
            branchCount: branches.length
        }
    }

    async getName(): Promise<string> {
        const result = await this.account.runLocal('getName', {});
        return result.decoded?.output.value0;
    }

    async getBranches(): Promise<TGoshBranch[]> {
        const result = await this.account.runLocal('getAllAddress', {});
        return result.decoded?.output.value0.map((item: any) => ({
            name: item.key,
            commitAddr: item.value,
            snapshot: item.snapshot
        }));
    }

    async getBranch(name: string): Promise<TGoshBranch> {
        const result = await this.account.runLocal('getAddrBranch', { name });
        const decoded = result.decoded?.output.value0;
        return {
            name: decoded.key,
            commitAddr: decoded.value,
            snapshot: decoded.snapshot
        }
    }

    async getSnapshotAddr(branchName: string, filePath: string): Promise<string> {
        const result = await this.account.runLocal(
            'getSnapAddr',
            { branch: branchName, name: filePath }
        );
        return result.decoded?.output.value0;
    }

    async getCommitAddr(branchName: string, commitSha: string): Promise<string> {
        const result = await this.account.runLocal(
            'getCommitAddr',
            {
                nameBranch: branchName,
                nameCommit: commitSha
            }
        );
        return result.decoded?.output.value0;
    }
}

export class GoshCommit implements IGoshCommit {
    abi: any = GoshCommitABI;
    account: Account;
    address: string;
    meta?: {
        repoAddr: string;
        branchName: string;
        sha: string;
        content: {
            title: string;
            message: string;
            blobs: {
                sha: string;
                name: string;
                diff: TDiffData[];
            }[];
        }
        parent1Addr: string;
        parent2Addr: string;
    }

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async load(): Promise<void> {
        const meta = await this.getCommit();
        this.meta = {
            repoAddr: meta.repo,
            branchName: meta.branch,
            sha: meta.sha,
            content: JSON.parse(meta.content),
            parent1Addr: meta.parent1,
            parent2Addr: meta.parent2
        }
    }

    async getCommit(): Promise<any> {
        const result = await this.account.runLocal('getCommit', {});
        return result.decoded?.output;
    }

    async getName(): Promise<string> {
        const result = await this.account.runLocal('getNameCommit', {});
        return result.decoded?.output.value0;
    }

    async getParent(): Promise<string[]> {
        const result = await this.account.runLocal('getParent', {});
        return result.decoded?.output.value0;
    }

    async getBlobs(): Promise<string[]> {
        const result = await this.account.runLocal('getBlobs', {});
        return result.decoded?.output.value0;
    }

    async getBlobAddr(blobSha: string): Promise<string> {
        const result = await this.account.runLocal(
            'getBlobAddr',
            { nameBlob: blobSha }
        );
        return result.decoded?.output.value0;
    }
}

export class GoshBlob implements IGoshBlob {
    abi: any = GoshBlobABI;
    account: Account;
    address: string;
    meta?: { sha: string; content: string; commitAddr: string; };

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async load(): Promise<void> {
        const meta = await this.getBlob();
        this.meta = {
            sha: meta.sha,
            content: meta.content,
            commitAddr: meta.commit,
        }
    }

    async getBlob(): Promise<any> {
        const result = await this.account.runLocal('getBlob', {});
        return result.decoded?.output;
    }
}

export class GoshSnapshot implements IGoshSnapshot {
    abi: any = GoshSnapshotABI;
    account: Account;
    address: string;
    meta?: {
        name: string;
        content: string;
    };

    constructor(client: TonClient, address: string) {
        this.address = address;
        this.account = new Account({ abi: this.abi }, { client, address });
    }

    async load(): Promise<void> {
        this.meta = {
            name: await this.getName(),
            content: await this.getSnapshot()
        }
    }

    async getName(): Promise<string> {
        const result = await this.account.runLocal('getName', {});
        return result.decoded?.output.value0;
    }

    async getSnapshot(): Promise<any> {
        const result = await this.account.runLocal('getSnapshot', {});
        return result.decoded?.output.value0;
    }
}
