import { useState, useEffect, useRef } from "react";
import Container from '@mui/material/Container';
import { useParams, Navigate, useLocation } from "react-router-dom";
import ReactMarkdown from 'react-markdown';
import rehypeRaw from 'rehype-raw';
import styles from './Content.module.scss';
import classnames from "classnames/bind";

const cnb = classnames.bind(styles);

export const Content = ({title, path}: {title?: string, path?: string}) => {
  
  const { id } = useParams<{id: string}>();
  const location = useLocation();
  const ref = useRef<HTMLElement>() as React.MutableRefObject<HTMLElement>;
  const [content, setContent] = useState<any>(null);

  useEffect(() => {
    setContent('');
    async function getContent () {
      const file = await import(`./../../content/${id || path}.md`);
      const response = await fetch(file.default);
      const markdown = await response.text();
      await setContent(markdown);
    }
    getContent();
  }, [id]);

  useEffect(() => {
    if (location.hash && ref && ref.current && content) ref.current.querySelector(location.hash)!.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, [content, location.hash]);

  if ( id === '' ) return (<Navigate
    to={{
      pathname: "/"
    }}
  />);

  if (content === null ) return (<></>);

  return (
    <Container className={cnb("content")}>
      <h1>{title}</h1>
      <section className="content-wrapper" ref={ref}>
        <ReactMarkdown rehypePlugins={[rehypeRaw]}>{content}</ReactMarkdown>
      </section>
    </Container>
  );
};

export default Content;
