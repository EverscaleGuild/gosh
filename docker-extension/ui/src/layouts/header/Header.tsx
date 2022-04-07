import { useState, useEffect } from "react";

import Box from '@mui/material/Box';
import Paper from '@mui/material/Paper';
import { ReactComponent as Logo } from "../../assets/images/logo.svg";
import { Link } from "react-router-dom";
import styles from "./Header.module.scss";
import classnames from "classnames/bind";

const cn = classnames.bind(styles);

export const Header = ({location, ...props}: {location: string}) => {
  return (<>
    <header className={cn("header")}>
    <Box
      className={cn("navbar")}
      sx={{
        display: 'flex',
        flexWrap: 'wrap',
      }}
    > 
          <Link to={""} className={cn("logo")}><Logo/></Link>
      </Box>
    </header>
    </>
  );
};

export default Header;
