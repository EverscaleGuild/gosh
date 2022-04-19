import React from "react";
import { Field } from "formik";
import { Link } from "react-router-dom";
import { classNames } from "../../utils";
import { Loader } from "../../components";


type TFormCommitBlockProps = {
    urlBack?: string;
    className?: string;
    isDisabled?: boolean;
    isSubmitting?: boolean;
    extraFields?: any;
    extraButtons?: any;
}

const FormCommitBlock = (props: TFormCommitBlockProps) => {
    const { urlBack, className, isDisabled, isSubmitting, extraFields, extraButtons } = props;

    return (
        <div className={classNames('mt-5 border rounded px-4 py-3', className)}>
            <h3 className="text-lg font-semibold mb-2">Commit data</h3>
            <div>
                <Field
                    name="title"
                    inputProps={{
                        className: 'text-sm py-1.5 w-full',
                        autoComplete: 'off',
                        placeholder: 'Commit title'
                    }}
                />
            </div>
            <div className="mt-3">
                <Field
                    name="message"
                    component="texarea"
                    help="Markdown syntax is supported"
                    inputProps={{
                        className: 'text-sm py-1.5 w-full',
                        placeholder: 'Commit optional description'
                    }}
                />
            </div>

            {extraFields}

            <div className="flex mt-4 items-center gap-3">
                <button
                    className="btn btn--body font-medium px-4 py-2"
                    type="submit"
                    disabled={isDisabled}
                >
                    {isSubmitting && <Loader />}
                    Commit changes
                </button>
                {urlBack && (
                    <Link
                        to={urlBack}
                        className="px-4 py-2 border rounded font-medium text-rose-500 border-rose-500 hover:bg-rose-50"
                    >
                        Cancel
                    </Link>
                )}
                {extraButtons}
            </div>
        </div>
    );
}

export default FormCommitBlock;
