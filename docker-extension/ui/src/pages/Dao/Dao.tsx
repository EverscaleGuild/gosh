import React from "react";
import { useOutletContext } from "react-router-dom";
import CopyClipboard from "../../components/CopyClipboard";
import { shortString } from "../../utils";
import { TDaoLayoutOutletContext } from "../DaoLayout";
import ReposPage from "../Repos";


const DaoPage = () => {
    const { goshDao } = useOutletContext<TDaoLayoutOutletContext>();

    return (
        <div className="flex gap-4">
            <div className="grow">
                <ReposPage />
            </div>
            <div className="basis-3/12 bordered-block px-7 py-8">
                <h3 className="font-semibold text-base mb-4">Details</h3>

                <p className="text-sm text-gray-606060">
                    This is a Gosh test organization
                </p>

                <CopyClipboard
                    label={shortString(goshDao.address)}
                    className="mt-2"
                    componentProps={{
                        text: goshDao.address
                    }}
                />
            </div>
        </div>
    );
}

export default DaoPage;
