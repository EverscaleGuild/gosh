import { ReactNode, forwardRef } from "react";

import Dialog from '@mui/material/Dialog';

import IconButton from '@mui/material/IconButton';
import CloseIcon from '@mui/icons-material/Close';
import Slide from '@mui/material/Slide';
import { TransitionProps } from '@mui/material/transitions';

import styles from "./Modal.module.scss";
import classnames from "classnames/bind";

const cnb = classnames.bind(styles);

interface ModalProps {
  show: boolean,
  onHide: () => void,
  className?: string,
  [key: string]: any
}


export const Overlay = ({
  show,
  onHide,
  className,
  children
}: ModalProps & {children: ReactNode}) => {
  const Transition = forwardRef(function Transition(
    props: TransitionProps & {
      children: React.ReactElement;
    },
    ref: React.Ref<unknown>,
  ) {
    return <Slide direction="up" ref={ref} {...props} />;
  });
  return (
<>
{show && <Dialog
  fullScreen
  hideBackdrop
  keepMounted={false}
  open={show}
  onClose={onHide}
  TransitionComponent={Transition}
  className={cnb(className)}
  closeAfterTransition
>

    <IconButton
      edge="start"
      color="inherit"
      onClick={onHide}
      aria-label="close"
      className={cnb("close")}
    >
      <CloseIcon />
    </IconButton>
    <>{children}</>
</Dialog>}</>
  );
};


export default Overlay;
