import React, { useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useRecoilValue } from "recoil";
import BranchSelect from "../../components/BranchSelect";
import { goshBranchesAtom, goshCurrBranchSelector } from "../../store/gosh.state";
import { TGoshBranch } from "../../types/types";


const PullsPage = () => {
    const { daoName, repoName } = useParams();
    const navigate = useNavigate();
    const branches = useRecoilValue(goshBranchesAtom);
    const defaultBranch = useRecoilValue(goshCurrBranchSelector('main'));
    const [branchFrom, setBranchFrom] = useState<TGoshBranch | undefined>(defaultBranch);
    const [branchTo, setBranchTo] = useState<TGoshBranch | undefined>(defaultBranch);

    return (
        <div className="bordered-block px-7 py-8">
            <div className="flex items-center gap-x-4">
                <BranchSelect
                    branch={branchFrom}
                    branches={branches}
                    onChange={(selected) => {
                        if (selected) {
                            setBranchFrom(selected);
                        }
                    }}
                />

                <BranchSelect
                    branch={branchTo}
                    branches={branches}
                    onChange={(selected) => {
                        if (selected) {
                            setBranchTo(selected);
                        }
                    }}
                />
                <button
                    className="btn btn--body px-3 py-1.5 !font-normal !text-sm"
                    disabled={branchFrom?.name === branchTo?.name}
                    onClick={() => {
                        navigate(`/organizations/${daoName}/repositories/${repoName}/pulls/create?from=${branchFrom?.name}&to=${branchTo?.name}`);
                    }}
                >
                    Create pull request
                </button>
            </div>

            <div className="mt-5">
                <div className="text-rose-400 mt-5">
                    <p>Generic only pull requests are available now</p>
                </div>
            </div>
        </div>
    );
}

export default PullsPage;
