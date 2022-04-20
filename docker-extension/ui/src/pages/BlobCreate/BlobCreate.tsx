import React, { useState } from "react";
import { Field, Form, Formik } from "formik";
import { Link, useNavigate, useOutletContext, useParams } from "react-router-dom";
import { TRepoLayoutOutletContext } from "./../RepoLayout";
import { useMonaco } from "@monaco-editor/react";
import { generateDiff, getCodeLanguageFromFilename, sha1 } from "./../../utils";
import * as Yup from "yup";
import { Tab } from "@headlessui/react";
import BlobEditor from "./../../components/Blob/Editor";
import BlobPreview from "./../../components/Blob/Preview";
import FormCommitBlock from "./FormCommitBlock";
import { useRecoilValue } from "recoil";
import { goshCurrBranchSelector } from "./../../store/gosh.state";
import { useGoshRepoBranches } from "./../../hooks/gosh.hooks";



type TFormValues = {
    name: string;
    content: string;
    title: string;
    message: string;
}

const BlobCreatePage = () => {
    const { daoName, repoName, branchName = 'main' } = useParams();
    const { goshRepo, goshWallet } = useOutletContext<TRepoLayoutOutletContext>();
    const { updateBranch } = useGoshRepoBranches(goshRepo);

    const branch = useRecoilValue(goshCurrBranchSelector(branchName));
    const navigate = useNavigate();
    const monaco = useMonaco();
    const [blobCodeLanguage, setBlobCodeLanguage] = useState<string>('plaintext');
    const [activeTab, setActiveTab] = useState<number>(0);
    const urlBack = `/organizations/${daoName}/repositories/${repoName}/tree/${branchName}`;

    const onCommitChanges = async (values: TFormValues) => {
        try {
            if (!goshWallet) throw Error('Can not get GoshWallet');
            if (!repoName) throw Error('Repository is undefined');
            if (!branch) throw Error('Branch is undefined');

            // Prepare commit data
            const blobSha = sha1(values.content, 'blob');
            const commitData = {
                title: values.title,
                message: values.message,
                blobs: [
                    {
                        sha: blobSha,
                        name: values.name,
                        diff: await generateDiff(monaco, values.content)
                    }
                ]
            };
            const commitDataStr = JSON.stringify(commitData)
            const commitSha = sha1(commitDataStr, 'commit');

            // Deploy commit, blob, diff
            await goshWallet.createCommit(
                repoName,
                branchName,
                commitSha,
                commitDataStr,
                branch.commitAddr,
                '0:0000000000000000000000000000000000000000000000000000000000000000'
            )
            await goshWallet.createBlob(repoName, commitSha, blobSha, values.content);
            await goshWallet.createDiff(repoName, branchName, values.name, values.content);

            await updateBranch(branch.name);
            navigate(urlBack);
        } catch (e: any) {
            alert(e.message);
        }
    }

    return (
        <div className="bordered-block px-7 py-8">
            <Formik
                initialValues={{ name: '', content: '', title: '', message: '' }}
                validationSchema={Yup.object().shape({
                    name: Yup.string().required('Field is required'),
                    title: Yup.string().required('Field is required')
                })}
                onSubmit={onCommitChanges}
            >
                {({ values, setFieldValue, isSubmitting, handleBlur }) => (
                    <Form>
                        <div className="flex gap-3 items-baseline justify-between ">
                            <div className="flex items-baseline">
                                <Link
                                    to={`/organizations/${daoName}/repositories/${repoName}/tree/${branchName}`}
                                    className="font-medium text-extblue hover:underline"
                                >
                                    {repoName}
                                </Link>
                                <span className="mx-2">/</span>
                                <div>
                                    <Field
                                        name="name"
                                        errorEnabled={false}
                                        inputProps={{
                                            className: '!text-sm !px-2.5 !py-1.5',
                                            autoComplete: 'off',
                                            placeholder: 'Name of new file',
                                            disabled: !monaco || activeTab === 1,
                                            onBlur: (e: any) => {
                                                // Formik `handleBlur` event
                                                handleBlur(e);

                                                // Resolve file code language by it's extension
                                                // and update editor
                                                const language = getCodeLanguageFromFilename(
                                                    monaco,
                                                    e.target.value
                                                );
                                                setBlobCodeLanguage(language);

                                                // Set commit title
                                                setFieldValue('title', `Create ${e.target.value}`);
                                            }
                                        }}
                                    />
                                </div>
                                <span className="mx-2">in</span>
                                <span>{branchName}</span>
                            </div>

                            <Link
                                to={urlBack}
                                className="btn btn--body px-3 py-1.5 !text-sm !font-normal"
                            >
                                Discard changes
                            </Link>
                        </div>

                        <div className="mt-5 border rounded overflow-hidden">
                            <Tab.Group
                                defaultIndex={activeTab}
                                onChange={(index) => setActiveTab(index)}
                            >
                                <Tab.List
                                >
                                    <Tab
                                    >
                                        Edit new file
                                    </Tab>
                                    <Tab
                                    >
                                        Preview
                                    </Tab>
                                </Tab.List>
                                <Tab.Panels
                                    className="-mt-[1px] border-t"
                                >
                                    <Tab.Panel>
                                        <BlobEditor
                                            language={blobCodeLanguage}
                                            value={values.content}
                                            onChange={(value) => setFieldValue('content', value)}
                                        />
                                    </Tab.Panel>
                                    <Tab.Panel>
                                        <BlobPreview
                                            language={blobCodeLanguage}
                                            value={values.content}
                                        />
                                    </Tab.Panel>
                                </Tab.Panels>
                            </Tab.Group>
                        </div>

                        <FormCommitBlock
                            urlBack={urlBack}
                            isDisabled={!monaco || isSubmitting}
                            isSubmitting={isSubmitting}
                        />
                    </Form>
                )}
            </Formik>
        </div>
    );
}

export default BlobCreatePage;
