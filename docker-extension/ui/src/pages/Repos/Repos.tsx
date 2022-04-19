import React, { useState } from "react";
import { Link, useOutletContext, useParams } from "react-router-dom";
import { useGoshRoot } from "../../hooks/gosh.hooks";
import { GoshRepository } from "../../types/classes";
import { IGoshRepository } from "../../types/types";
import { useQuery } from "react-query";
import RepoListItem from "./RepoListItem";
import { TDaoLayoutOutletContext } from "../DaoLayout";


const RepositoriesPage = () => {
    const [search, setSearch] = useState<string>();
    const goshRoot = useGoshRoot();
    const { goshDao } = useOutletContext<TDaoLayoutOutletContext>();
    const { daoName } = useParams();
    const repoListQuery = useQuery(
        ['repositoryList'],
        async (): Promise<IGoshRepository[]> => {
            if (!goshRoot) return [];

            // Get GoshDaoRepoCode by GoshDao address and get all repos addreses
            const repoCode = await goshRoot.getDaoRepoCode(goshDao.address);
            console.debug('Repo code', repoCode);
            const reposAddrs = await goshRoot.account.client.net.query_collection({
                collection: 'accounts',
                filter: {
                    code: { eq: repoCode }
                },
                result: 'id'
            });
            console.debug('GoshRepos addreses:', reposAddrs?.result || []);

            // Create GoshRepository objects
            const repos = await Promise.all(
                (reposAddrs?.result || []).map(async (item) => {
                    const repo = new GoshRepository(goshRoot.account.client, item.id);
                    await repo.load();
                    return repo;
                })
            );
            console.debug('GoshRepos:', repos);
            return repos;
        },
        {
            enabled: !!goshRoot,
            select: (data) => {
                if (!search) return data;
                const pattern = new RegExp(search, 'i');
                return data.filter((repo) => repo.meta && repo.meta.name.search(pattern) >= 0);
            }
        }
    );

    return (
        <div className="bordered-block px-7 py-8">
            <h3 className="font-semibold text-base mb-4">Repositories</h3>
            <div className="flex flex-wrap gap-4 justify-between">
                <div className="input grow">
                    <input
                        type={'text'}
                        autoComplete={'off'}
                        placeholder={'Find repository...'}
                        className="element !py-1.5 !text-sm"
                        onChange={(event) => setSearch(event.target.value)}
                    />
                </div>

                <Link
                    className="btn btn--body px-4 py-1.5 text-sm !font-normal"
                    to={`/organizations/${goshDao.meta?.name}/repositories/create`}
                >
                    New repository
                </Link>
            </div>

            <div className="mt-5 divide-y divide-gray-c4c4c4">
                {(repoListQuery.isIdle || repoListQuery.isLoading) && (
                    <p className="text-sm text-gray-500 text-center py-3">
                        Loading repositories...
                    </p>
                )}

                {repoListQuery.isFetched && !repoListQuery.data?.length && (
                    <p className="text-sm text-gray-500 text-center py-3">
                        There are no repositories
                    </p>
                )}

                {repoListQuery.data?.map((repository, index) => (
                    daoName && <RepoListItem key={index} daoName={daoName} repository={repository} />
                ))}
            </div>
        </div>
    );
}

export default RepositoriesPage;
