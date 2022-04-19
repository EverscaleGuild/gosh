import React from "react";
import { Link } from "react-router-dom";
import CopyClipboard from "../../components/CopyClipboard";
import { IGoshRepository } from "../../types/types";
import { shortString } from "../../utils";


type TRepositoryListItemProps = {
    daoName: string;
    repository: IGoshRepository
}

const RepositoryListItem = (props: TRepositoryListItemProps) => {
    const { daoName, repository } = props;

    return (
        <div className="py-3">
            <Link
                className="text-xl font-semibold hover:underline"
                to={`/organizations/${daoName}/repositories/${repository.meta?.name}`}
            >
                {repository.meta?.name}
            </Link>

            <div className="text-sm text-gray-606060">
                Gosh test repository
            </div>

            <div className="flex gap-1 mt-2">
                {['gosh', 'vcs', 'ever', 'use', 'enjoy'].map((value, index) => (
                    <button
                        key={index}
                        type="button"
                        className="rounded-2xl bg-extblue/25 text-xs text-extblue px-2 py-1 hover:bg-extblue hover:text-white"
                    >
                        {value}
                    </button>
                ))}
            </div>

            <div className="flex gap-4 mt-3 text-xs text-gray-606060 justify-between">
                <div className="flex gap-4">
                    <div>

                        Language
                    </div>
                    <div>

                        {repository.meta?.branchCount}
                    </div>
                    <div>

                        22
                    </div>
                </div>
                <CopyClipboard
                    componentProps={{
                        text: repository.address
                    }}
                    className="hover:text-gray-050a15"
                    label={shortString(repository.address)}
                />
            </div>
        </div>
    );
}

export default RepositoryListItem;
