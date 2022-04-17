import Container from '@mui/material/Container';
import Typography from '@mui/material/Typography';
// import { Link } from "react-router-dom";
import Link from '@mui/material/Link';
import Grid from '@mui/material/Grid';
import Paper from '@mui/material/Paper';
import styles from "./Footer.module.scss";

export const Footer = () => {
  return (
    <Paper
      elevation={3}
      className={styles['footer-wrapper']}
    >
    <footer className={styles.footer}>
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
  );
};

export default Footer;
