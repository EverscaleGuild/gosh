import React, { useEffect, useState } from "react";
import { useOutletContext, useParams } from "react-router-dom";
// import { GoshBlob, GoshCommit } from "../../types/classes";
import { IGoshBlob, IGoshCommit, IGoshRepository } from "../../types/types";
import { TRepoLayoutOutletContext } from "../RepoLayout";
import { useMonaco } from "@monaco-editor/react";
import { getCodeLanguageFromFilename, restoreFromDiff } from "../../utils";
import BlobDiffPreview from "../../components/Blob/DiffPreview";
import { GoshBlob, GoshCommit } from "../../types/classes";


const CommitPage = () => {
    const { goshRepo } = useOutletContext<TRepoLayoutOutletContext>();
    const { branchName, commitName } = useParams();
    const monaco = useMonaco();
    const [commit, setCommit] = useState<IGoshCommit>();
    const [blobs, setBlobs] = useState<IGoshBlob[]>();

    useEffect(() => {
        const getCommit = async (repo: IGoshRepository, branch: string, sha: string) => {
            const address = await repo.getCommitAddr(branch, sha);
            const commit = new GoshCommit(repo.account.client, address);
            await commit.load();

            const blobAddrs = await commit.getBlobs();
            const blobs = await Promise.all(
                blobAddrs.map(async (addr) => {
                    const blob = new GoshBlob(commit.account.client, addr);
                    await blob.load();
                    return blob;
                })
            );
            console.debug('Blob addrs', blobAddrs);
            console.debug('Blobs', blobs);

            setCommit(commit);
            setBlobs(blobs);
        }

        if (goshRepo && branchName && commitName) getCommit(goshRepo, branchName, commitName);
    }, [goshRepo, branchName, commitName]);

    return (
        <div className="bordered-block px-7 py-8">
            {(!monaco || !commit) && (<p>Loading commit...</p>)}
            {monaco && commit && (
                <>
                    <div>
                        <div className="font-medium py-2">
                            {commit.meta?.content.title}
                        </div>

                        {commit.meta?.content.message && (
                            <div className="mb-2 text-gray-050a15/65 text-sm">
                                {commit.meta.content.message}
                            </div>
                        )}

                        <div className="flex border-t justify-end px-3 py-1">
                            <div className="text-gray-050a15/75 text-xs">
                                <span className="mr-2 text-gray-050a15/65">sha1</span>
                                {commit.meta?.sha}
                            </div>
                        </div>
                    </div>

                    {commit.meta?.content.blobs.map((item, index) => {
                        const blob = blobs?.find((blob) => blob.meta?.sha === item.sha);
                        const language = getCodeLanguageFromFilename(monaco, item.name);
                        const original = restoreFromDiff(blob?.meta?.content || '', item.diff);
                        return (
                            <div key={index} className="my-5 border rounded overflow-hidden">
                                <div className="bg-gray-100 border-b px-3 py-1.5 text-sm font-semibold">
                                    {item.name}
                                </div>
                                <BlobDiffPreview
                                    original={original}
                                    modified={blob?.meta?.content}
                                    modifiedLanguage={language}
                                />
                            </div>
                        );
                    })}
                </>
            )}
        </div>
    );
}

export default CommitPage;
