import { ScrollViewStyleReset } from "expo-router/html";
import type { ReactNode } from "react";

export default function Root({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />
        <title>Jingle</title>
        <ScrollViewStyleReset />
        <style
          dangerouslySetInnerHTML={{
            __html: `
              html, body, #root { height: 100%; background: #070708; }
              body { margin: 0; user-select: none; -webkit-user-select: none; }
              input, textarea { user-select: text; -webkit-user-select: text; }
              ::-webkit-scrollbar { width: 0; height: 0; }
            `,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
