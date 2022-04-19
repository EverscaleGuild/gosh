import React, { useState } from "react";
import { Field, Form, Formik, FormikHelpers } from "formik";
import { useMutation } from "react-query";
import { Link, useOutletContext, useParams } from "react-router-dom";
import BranchSelect from "./../../components/BranchSelect";
import { Loader } from "./../../components";
import { TGoshBranch } from "./../../types/types";
import { TRepoLayoutOutletContext } from "./../RepoLayout";
import * as Yup from "yup";
import { useRecoilValue } from "recoil";
import { goshCurrBranchSelector } from "./../../store/gosh.state";
import { useGoshRepoBranches } from "./../../hooks/gosh.hooks";


type TCreateBranchFormValues = {
    newName: string;
    from?: TGoshBranch;
}

export const BranchesPage = () => {
    const { daoName, repoName } = useParams();
    const { goshRepo, goshWallet } = useOutletContext<TRepoLayoutOutletContext>();
    const [branchName, setBranchName] = useState<string>('main');
    const { branches, updateBranches } = useGoshRepoBranches(goshRepo);
    const branch = useRecoilValue(goshCurrBranchSelector(branchName));
    const [search, setSearch] = useState<string>();
    const [branchesOnMutation, setBranchesOnMutation] = useState<string[]>([]);
    const branchDeleteMutation = useMutation(
        (name: string) => {
            if (!repoName) throw Error('Repository name is undefined');
            return goshWallet.deleteBranch(repoName, name);
        },
        {
            onMutate: (variables) => {
                setBranchesOnMutation((value) => [...value, variables]);
            },
            onSuccess: () => updateBranches(),
            onError: (error: any) => {
                console.error(error);
                alert(error.message);
            },
            onSettled: (data, error, variables) => {
                setBranchesOnMutation((value) => value.filter((item) => item !== variables));
            }
        }
    )

    const onBranchCreate = async (
        values: TCreateBranchFormValues,
        helpers: FormikHelpers<any>
    ) => {
        try {
            if (!repoName) throw Error('Repository is undefined');
            if (!values.from) throw Error('From branch is undefined');

            await goshWallet.createBranch(
                repoName,
                values.newName,
                values.from.name,
                values.from.snapshot.length
            );
            await updateBranches();
            helpers.resetForm();
        } catch (e: any) {
            console.error(e);
            alert(e.message);
        }
    }

    const onBranchDelete = (name: string) => {
        if (window.confirm(`Delete branch '${name}'?`)) {
            branchDeleteMutation.mutate(name);
        }
    }

    return (
        <div className="bordered-block px-7 py-8">
            <div className="flex justify-between gap-4">
                <Formik
                    initialValues={{ newName: '', from: branch }}
                    onSubmit={onBranchCreate}
                    validationSchema={Yup.object().shape({
                        newName: Yup.string()
                            .notOneOf((branches).map((b) => b.name), 'Branch exists')
                            .required('Branch name is required')
                    })}
                >
                    {({ isSubmitting, setFieldValue }) => (
                        <Form className="flex items-center">
                            <BranchSelect
                                branch={branch}
                                branches={branches}
                                onChange={(selected) => {
                                    if (selected) {
                                        setBranchName(selected?.name);
                                        setFieldValue('from', selected);
                                    }
                                }}
                            />
                            <span className="mx-3">

                            </span>
                            <div>
                                <Field
                                    name="newName"
                                    errorEnabled={false}
                                    inputProps={{
                                        placeholder: 'Branch name',
                                        autoComplete: 'off',
                                        className: '!text-sm !py-1.5'
                                    }}
                                />
                            </div>
                            <button
                                type="submit"
                                className="btn btn--body px-3 py-1.5 ml-3 !text-sm"
                                disabled={isSubmitting}
                            >
                                {isSubmitting && <Loader/>}
                                Create branch
                            </button>
                        </Form>
                    )}
                </Formik>

                <div className="input basis-1/4">
                    <input
                        type="text"
                        className="element !text-sm !py-1.5"
                        placeholder="Search branch (disabled)"
                        disabled={true}
                        onChange={(e) => setSearch(e.target.value)}
                    />
                </div>
            </div>

            <div className="mt-5 divide-y divide-gray-c4c4c4">
                {branches.map((branch, index) => (
                    <div key={index} className="flex gap-4 items-center px-3 py-2 text-sm">
                        <div className="grow">
                            <Link
                                to={`/organizations/${daoName}/repositories/${repoName}/tree/${branch.name}`}
                                className="hover:underline"
                            >
                                {branch.name}
                            </Link>
                        </div>
                        <div>
                            {branch.name !== 'main' && (
                                <button
                                    type="button"
                                    className="px-2.5 py-1.5 text-white text-xs rounded bg-rose-600
                                        hover:bg-rose-500 disabled:bg-rose-400"
                                    onClick={() => onBranchDelete(branch.name)}
                                    disabled={branchDeleteMutation.isLoading && branchesOnMutation.indexOf(branch.name) >= 0}
                                >
                                    {branchDeleteMutation.isLoading && branchesOnMutation.indexOf(branch.name) >= 0
                                        ? <Loader />
                                        : <></>
                                    }
                                    <span className="ml-2">Delete</span>
                                </button>
                            )}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}

export default BranchesPage;
