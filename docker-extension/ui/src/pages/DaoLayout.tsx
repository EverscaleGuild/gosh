import React from "react";
import { Link, NavLink, Outlet, useParams } from "react-router-dom";
import { Loader } from "../components";
import { useGoshDao } from "../hooks/gosh.hooks";
import { IGoshDao } from "../types/types";
import { classNames } from "../utils";


export type TDaoLayoutOutletContext = {
    goshDao: IGoshDao;
}

const DaoLayout = () => {
    const { daoName } = useParams();
    const goshDao = useGoshDao(daoName);
    const tabs = [
        { to: `/organizations/${goshDao?.meta?.name}`, title: 'Overview' },
        { to: `/organizations/${goshDao?.meta?.name}/repos`, title: 'Repositories' }
    ];

    return (
        <div className="container my-10">
            {!goshDao && (
                <>
                    <Loader/>
                    Loading organization
                </>
            )}

            {goshDao && (
                <>
                    <h1 className="mb-6">
                        <Link to={`/organizations/${goshDao.meta?.name}`} className="font-semibold text-2xl">
                            {goshDao.meta?.name}
                        </Link>
                    </h1>

                    <div className="flex gap-x-6 mb-6">
                        {tabs.map((item, index) => (
                            <NavLink
                                key={index}
                                to={item.to}
                                end
                                className={({ isActive }) => classNames(
                                    'text-base text-gray-050a15/50 hover:text-gray-050a15 py-1.5 px-2',
                                    isActive ? '!text-gray-050a15 border-b border-b-gray-050a15' : null
                                )}
                            >
                                {item.title}
                            </NavLink>
                        ))}
                    </div>

                    <Outlet context={{ goshDao }} />
                </>
            )}
        </div>
    );
}

export default DaoLayout;
