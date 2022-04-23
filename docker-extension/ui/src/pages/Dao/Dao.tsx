import { useOutletContext, Outlet, Link } from "react-router-dom";
import CopyClipboard from "./../../components/CopyClipboard";
import { shortString } from "./../../utils";
import { TDaoLayoutOutletContext } from "./../DaoLayout";
import { Loader, FlexContainer, Flex } from "./../../components";
import ReposPage from "./../Repos";
import Button from '@mui/material/Button';
import { PlusIcon, CollectionIcon, UsersIcon, ArrowRightIcon, EmojiSadIcon } from '@heroicons/react/outline';
import InputBase from '@mui/material/InputBase';
import { Typography } from "@mui/material";

import styles from './Dao.module.scss';
import classnames from "classnames/bind";

const cnb = classnames.bind(styles);

const DaoPage = () => {
    const { goshDao } = useOutletContext<TDaoLayoutOutletContext>();

    return (
        <>
    
          {/* <CreateDaoModal
            showModal={showModal}
            handleClose={() => {
              setShowModal(false);
              navigate("/account/organizations");
            }}
          /> */}
          <div className="left-column">
          {/* <h2 className="font-semibold text-2xl mb-5">User account</h2> */}
          {goshDao && (<>
            <h2 className="color-faded">{goshDao.meta?.name}</h2>
            <Outlet context={{ goshDao }} />
            <Typography>
              This is a Gosh test organization
            </Typography>
              <CopyClipboard
                className={cnb("address")}
                label={shortString(goshDao.address)}
                componentProps={{
                    text: goshDao.address
                }}
              />
            </>
          )}
  
        </div>
        <div className="right-column">
        {!goshDao && (
                <>
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
                                disabled
                                // icon={<Icon icon={"arrow-up-right"}/>}
                                // iconAnimation="right"
                                // iconPosition="after"
                            ><PlusIcon/> Create</Button>
                        </Link>
                    </Flex>
                </FlexContainer>
                <InputBase
                  className="input-field"
                  type="text"
                  placeholder="Search repositories"
                  autoComplete={'off'}
                  onChange={() =>{}}
                />
                <div className="divider"></div>
          
              </div>
            <div className="loader">
            <Loader />
            Loading {"repositories"}...
            </div>
                </>
            )}
            {goshDao && (
                <ReposPage />
            )}
        </div>
    </>
    );
}

export default DaoPage;
