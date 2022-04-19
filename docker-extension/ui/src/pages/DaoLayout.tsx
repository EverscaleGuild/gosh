import React from "react";
import { Link, NavLink, Outlet, useParams } from "react-router-dom";
import { Loader } from "./../components";
import { useGoshDao } from "./../hooks/gosh.hooks";
import { IGoshDao } from "./../types/types";
import { classNames } from "./../utils";
import CopyClipboard from "./../components/CopyClipboard";
import { shortString } from "./../utils";

import Container from '@mui/material/Container';
import List from '@mui/material/List';
import ListItem from '@mui/material/ListItem';
import ListItemButton from '@mui/material/ListItemButton';
import ListItemIcon from '@mui/material/ListItemIcon';
import ListItemText from '@mui/material/ListItemText';
import DaoPage from "./Dao";
import ReposPage from "./Repos";


export type TDaoLayoutOutletContext = {
    goshDao: IGoshDao;
}

const DaoLayout = () => {
    const { daoName } = useParams();
    const goshDao = useGoshDao(daoName);
    const tabs = [
        { to: `/organizations/${goshDao?.meta?.name}`, title: 'Overview' },
        { to: `/organizations/${goshDao?.meta?.name}/repositories`, title: 'Repositories' }
    ];

    return (
        <Container
            className={"content-container"}
        >
            <Outlet context={{ goshDao }} />
      </Container>
    );
}

export default DaoLayout;
