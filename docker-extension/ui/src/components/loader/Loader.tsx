import { FunctionComponent } from "react";

import styles from "./Loader.module.scss";
import classnames from "classnames/bind";

const cn = classnames.bind(styles);

export const Loader:FunctionComponent<{className?: string}> = ({className}) => (
  <svg className={cn("loader", className)}>
    <circle cx="20" cy="20" r="12"></circle>
  </svg>
);
export default Loader;
