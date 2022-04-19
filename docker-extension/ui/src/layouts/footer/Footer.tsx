import { useState } from 'react';
import Button from '@mui/material/Button';
import Container from '@mui/material/Container';
import Typography from '@mui/material/Typography';
import Link from '@mui/material/Link';
import Grid from '@mui/material/Grid';
import Paper from '@mui/material/Paper';
import { DockerClient } from "../../client";
import { Overlay } from "../../components";
import { Content } from "../../pages";

import styles from "./Footer.module.scss";
import classnames from "classnames/bind";

const cnb = classnames.bind(styles);

const Help = ({showModal, handleClose}: {
  showModal: boolean,
  handleClose: any,
}) => {
  return (
    <Overlay
      show={showModal}
      onHide={handleClose}
      className={cnb("modal")}
    >
      <Content path="help" />
    </Overlay>
  )
};

export const Footer = () => {
  const [showModal, setShowModal] = useState<boolean>(false);

  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const handleClick = () => {
    DockerClient.getContainers()
    .then((value) => {
      console.log(value);
      //setContainers(value || []);
      //TODO
    });
  }

  return (<>
    <Help
      showModal={showModal}
      handleClose={handleClose}
    />
    <Paper
      elevation={2}
      className={styles['footer-wrapper']}
    >
    <footer className={styles.footer}>
      <div className={styles["button-block"]}>
        <Button
          color="primary"
          size="medium"
          disableElevation
          // icon={<Icon icon={"arrow-up-right"}/>}
          // iconAnimation="right"
          // iconPosition="after"
          onClick={handleShow}
        >Help <></></Button>
        <Button
          disableElevation
          color="primary"
          variant="contained"
          size="medium"
          onClick={handleClick}
        >Update data</Button>
      </div>
      <Container maxWidth={false}>
      <Grid
        container
        direction="row"
        justifyContent="left"
        alignItems="center"
        spacing={3}
        className={styles.grid}
      > 
        <Grid item>
          <Typography>{(new Date()).getFullYear().toString()} &copy; Gosh</Typography>
        </Grid>
        <Grid item>
          <Link variant="body1" href="mailto:welcome@gosh.sh">welcome@gosh.sh</Link>
        </Grid>
      </Grid>
      </Container>
    </footer>
    </Paper>
  </>
  );
};

export default Footer;
