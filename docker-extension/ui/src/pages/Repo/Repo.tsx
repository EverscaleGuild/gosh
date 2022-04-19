import React, { useEffect, useState } from "react";
import { Link, useNavigate, useOutletContext, useParams } from "react-router-dom";
import { IGoshRepository, IGoshSnapshot, TGoshBranch } from "./../../types/types";
import { TRepoLayoutOutletContext } from "./../RepoLayout";
import BranchSelect from "./../../components/BranchSelect";
import { GoshSnapshot } from "./../../types/classes";
import { useRecoilValue } from "recoil";
import { goshCurrBranchSelector } from "./../../store/gosh.state";
import { useGoshRepoBranches } from "./../../hooks/gosh.hooks";
import { Loader } from "./../../components";


const RepoPage = () => {
    const { goshRepo } = useOutletContext<TRepoLayoutOutletContext>();
    const { daoName, repoName, branchName = 'main' } = useParams();
    const navigate = useNavigate();
    const { branches } = useGoshRepoBranches(goshRepo);
    const branch = useRecoilValue(goshCurrBranchSelector(branchName));
    const [tree, setTree] = useState<IGoshSnapshot[]>();

    useEffect(() => {
        const getTree = async (repo: IGoshRepository, currBranch: TGoshBranch) => {
            setTree(undefined);
            const snapshots = await Promise.all(
                currBranch.snapshot.map(async (address) => {
                    const snapshot = new GoshSnapshot(repo.account.client, address);
                    await snapshot.load();
                    return snapshot;
                })
            );
            console.debug('GoshSnapshots:', snapshots);
            setTree(snapshots);
        }

        if (goshRepo && branch) getTree(goshRepo, branch);
    }, [goshRepo, branch]);

    return (
        <div className="bordered-block px-7 py-8">
            <div className="flex items-center justify-between gap-3">
                <div>
                    <BranchSelect
                        branch={branch}
                        branches={branches}
                        onChange={(selected) => {
                            if (selected) {
                                navigate(`/organizations/${daoName}/repositories/${repoName}/tree/${selected.name}`);
                            }
                        }}
                    />

                    <Link
                        to={`/organizations/${daoName}/repositories/${repoName}/branches`}
                        className="ml-4 text-sm text-gray-050a15/65 hover:text-gray-050a15"
                    >
                        <span className="mr-1 font-semibold">
                            {branches.length}
                        </span>
                        branches
                    </Link>

                    <Link
                        to={`/organizations/${daoName}/repositories/${repoName}/commits/${branchName}`}
                        className="ml-4 text-sm text-gray-050a15/65 hover:text-gray-050a15"
                    >
                        History
                    </Link>
                </div>

                <div className="flex gap-3">
                    <Link
                        to={`/organizations/${daoName}/repositories/${repoName}/blobs/create/${branchName}`}
                        className="btn btn--body px-4 py-1.5 text-sm !font-normal"
                    >
                        Add file
                    </Link>
                </div>
            </div>

            <div className="mt-5">
                {tree === undefined && (
                    <div className="text-gray-606060">
                        <Loader/>
                        Loading tree...
                    </div>
                )}

                {tree && !tree?.length && (
                    <div className="text-sm text-gray-606060 py-3">
                        There are no files yet
                    </div>
                )}

                {Boolean(tree?.length) && tree?.map((blob, index) => (
                    <div
                        key={index}
                        className="flex gap-x-4 py-3 border-b border-gray-300 last:border-b-0"
                    >
                        <div className="basis-1/4 text-sm font-medium">
                            <Link
                                className="hover:underline"
                                to={`/organizations/${daoName}/repositories/${repoName}/blob/${blob.meta?.name}`}
                            >
                                {blob.meta && blob.meta.name.split('/').slice(-1)}
                            </Link>
                        </div>
                        <div className="text-gray-500 text-sm">
                            {/* <Link
                                className="hover:underline"
                                to={`/repositories/${repoName}/commit/${blob.lastCommitSha}`}
                            >
                                {blob.lastCommitMsg.title}
                            </Link> */}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}

export default RepoPage;
