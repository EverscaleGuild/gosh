import React, { useState } from "react";
import { Link, useOutletContext, useParams, Outlet } from "react-router-dom";
import { useGoshRoot } from "./../../hooks/gosh.hooks";
import { GoshRepository } from "./../../types/classes";
import { IGoshRepository } from "./../../types/types";
import { useQuery } from "react-query";
import RepoListItem from "./RepoListItem";
import { TDaoLayoutOutletContext } from "./../DaoLayout";
import { Loader, LoaderDotsText, FlexContainer, Flex, Modal } from "./../../components";
import Button from '@mui/material/Button'
import { PlusIcon, CollectionIcon, UsersIcon, ArrowRightIcon, EmojiSadIcon } from '@heroicons/react/outline';
import InputBase from '@mui/material/InputBase';


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
        <>

      {/* <CreateDaoModal
        showModal={showModal}
        handleClose={() => {
          setShowModal(false);
          navigate("/account/organizations");
        }}
      /> */}
      <Outlet/>
      <div className="page-header">
        <FlexContainer
            direction="row"
            justify="space-between"
            align="flex-start"
        >
          <Flex>
              <h2>Repositories</h2>
          </Flex>
          <Flex>
                <Link
                    className="btn btn--body px-4 py-1.5 text-sm !font-normal"
                    to={`/organizations/repositories/create`}
                >
                  <Button
                      color="primary"
                      variant="contained"
                      size="medium"
                      className={"btn-icon"}
                      disableElevation
                      // icon={<Icon icon={"arrow-up-right"}/>}
                      // iconAnimation="right"
                      // iconPosition="after"
                  ><PlusIcon/> Create</Button>
              </Link>
          </Flex>
      </FlexContainer>
      <InputBase
        className="search-field"
        type="text"
        placeholder="Search repositories"
        autoComplete={'off'}
        onChange={(event) => setSearch(event.target.value)}
      />

    </div>
      <div className="divider"></div>
      <div className="mt-8">
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
{/* 
        <div className="divide-y divide-gray-c4c4c4">
            {goshDaos?.map((item, index) => (
              <Link
                key={index}
                to={`/organizations/${item.meta?.name}`}
                className="text-xl font-semibold hover:underline"
              >
                <FlexContainer
                  className="organization"
                  direction="column"
                  justify="space-between"
                  align="flex-start"
                >
                  <Flex>
                    <div className="arrow"><ArrowRightIcon/></div>
                    <div className="organization-title">
                      {item.meta?.name}
                    </div>
                    <div className="organization-description">
                      Organization description
                    </div>
                  </Flex>
                  <Flex
                    className="organization-footer"
                  >
                    <FlexContainer
                      direction="row"
                      justify="flex-start"
                      align="center"
                    >
                      <Flex>
                        <div className="badge"><CollectionIcon/> <LoaderDotsText className={"badge-loader"}/> repositories</div>
                      </Flex>
                      <Flex>
                        <div className="badge"><UsersIcon/> <LoaderDotsText className={"badge-loader"}/> members</div>
                      </Flex>
                    </FlexContainer>
                  </Flex>
                </FlexContainer>
              </Link>
            ))}
        </div> */}
      </div>
    </>
    );
}

export default RepositoriesPage;
