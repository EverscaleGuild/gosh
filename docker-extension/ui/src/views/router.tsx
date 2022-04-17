
import { BrowserRouter, Routes, Route, useLocation } from "react-router-dom";
import cn from "classnames";
import {
  isMobile
} from "react-device-detect";

import Main from "./main";
import Content from "./content";
import { Header, Footer } from "../layouts";

const Router = () => {
  const location:string = useLocation().pathname.split('/').filter(Boolean)[0];
  return (
    <div className={cn("ws-app", useLocation().pathname.split('/').filter(Boolean)[0], {"isMobile": isMobile, "main": !location})}>
      <Header
        location={location || "main"}
      />
      <main>
        <Routes>
          <Route path="/legal-notes/:id" element={<Content/>} />
        </Routes>
        <Main/>
      </main>
      <Footer />
    </div>
  );
};

export default Router;
