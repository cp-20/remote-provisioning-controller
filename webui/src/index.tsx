import { Hono } from 'hono';
import { createBunWebSocket } from 'hono/bun';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import { WSContext } from 'hono/ws';

const { upgradeWebSocket, websocket } = createBunWebSocket();

const app = new Hono();

app.get('/', (c) =>
  c.html(
    <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <script src="https://cdn.tailwindcss.com" />
        <script src="https://unpkg.com/htmx.org@2.0.3" />
        <script src="https://unpkg.com/htmx-ext-ws@2.0.1/ws.js" />
        <script
          // workaround for https://github.com/bigskysoftware/htmx/issues/1882
          dangerouslySetInnerHTML={{
            __html: `document.addEventListener("htmx:wsAfterMessage", (e) => {
                      const messagesDiv = document.getElementById("logs");
                      messagesDiv.scrollTop = messagesDiv.scrollHeight;
                    })`,
          }}
        />
      </head>
      <body class="max-w-3xl mx-auto py-4">
        <main class="space-y-8" hx-ext="ws" ws-connect="/ws">
          <h1 class="text-2xl">Remote Provisioning Controller</h1>
          <form hx-post="/deploy" hx-swap="none" class="space-y-4">
            <div class="grid grid-cols-[auto,1fr] gap-2">
              <label for="username-input" class="font-bold text-gray-700">
                ユーザー名
              </label>
              <input
                type="text"
                id="username-input"
                name="username"
                autocomplete="off"
                required
                class="rounded-sm border border-gray-400 px-2 py-1"
              />
              <label for="branch-input" class="font-bold text-gray-700">
                ブランチ名
              </label>
              <input
                type="text"
                id="branch-input"
                name="branch"
                autocomplete="off"
                required
                class="rounded-sm border border-gray-400 px-2 py-1"
              />
            </div>
            <button
              type="submit"
              class="bg-teal-500 hover:bg-teal-600 transition-colors py-2 rounded-sm text-white font-bold w-full"
            >
              デプロイ
            </button>
          </form>
          <div>
            <div
              id="logs"
              class="font-mono bg-gray-200 border border-gray-400 p-4 text-xs whitespace-pre-wrap max-h-[320px] overflow-y-scroll"
            />
          </div>
          <form hx-post="/config" hx-swap="none" class="flex flex-col gap-2">
            <label for="settings-textarea" class="font-bold text-gray-700">
              高度なデプロイ設定
            </label>
            <textarea
              id="config-textarea"
              name="config"
              autocomplete="off"
              class="rounded-sm border border-gray-400 bg-gray-100 px-2 py-1 text-xs font-mono"
              style={{ 'field-sizing': 'content' }}
              hx-get="/config"
              hx-swap="innerHTML"
              hx-trigger="load"
            />
            <button
              type="submit"
              class="bg-teal-500 hover:bg-teal-600 transition-colors py-2 rounded-sm text-white font-bold"
            >
              変更
            </button>
          </form>
        </main>
      </body>
    </html>
  )
);

type EventType = 'log' | 'config_updated';
class PubSub {
  logs: string[] = [];
  subscribers: WSContext<unknown>[] = [];

  constructor() {}

  private getPayload(type: EventType, message: string) {
    if (type === 'log') {
      this.logs.push(message);
      const now = new Date();
      const hour = now.getHours().toString().padStart(2, '0');
      const minute = now.getMinutes().toString().padStart(2, '0');
      const second = now.getSeconds().toString().padStart(2, '0');
      const millisecond = now.getMilliseconds().toString().padStart(3, '0');
      const timestamp = `${hour}:${minute}:${second}.${millisecond}`;
      return `<div id="logs" hx-swap-oob="beforeend"><div class="flex"><span class="text-gray-600">${timestamp} | </span><div>${message}</div>\n</div></div>`;
    }

    if (type === 'config_updated') {
      return `<span hx-swap-oob="innerHTML:#config-textarea">${message}</span>`;
    }

    const _: never = type;
    return message;
  }

  subscribe(ws: WSContext<unknown>) {
    this.subscribers.push(ws);
  }

  unsubscribe(ws: WSContext<unknown>) {
    this.subscribers = this.subscribers.filter((s) => s !== ws);
  }

  publish(type: EventType, message: string) {
    const payload = this.getPayload(type, message);
    this.subscribers.forEach((ws) => {
      ws.send(payload);
    });
  }
}
const pubsub = new PubSub();

const ansiToHtml = (ansiString: string) => {
  const ansiMap: Record<string, string> = {
    '0;34': 'text-blue-500',
    '0;32': 'text-green-500',
    '0;31': 'text-red-500',
    '2;29': 'text-gray-500',
  };

  const ansiRegex = /\x1b\[(\d;?\d*)m/g;

  return ansiString
    .replace(ansiRegex, (_, ansiCode) => {
      const cssClass = ansiMap[ansiCode];
      return cssClass ? `<span class="${cssClass}">` : '</span>';
    })
    .replace(/\x1b\[0m/g, '</span>');
};

const deployFormValidator = zValidator(
  'form',
  z.object({ username: z.string(), branch: z.string() })
);

const configFormValidator = zValidator(
  'form',
  z.object({ config: z.string() })
);

const configFile = Bun.file('../config.json');
const deployScript = '../scripts/deploy.sh';

let deployLock = false;
const system = '<span class="text-cyan-500 font-bold">[SYSTEM]</span>';

const routes = app
  .get('/config', async (c) => {
    const content = await configFile.text();
    return c.text(content);
  })
  .post('/config', configFormValidator, async (c) => {
    const { config: newConfig } = c.req.valid('form');
    await Bun.write(configFile, newConfig);
    pubsub.publish('config_updated', newConfig);
    pubsub.publish('log', `${system} 設定が更新されました`);
    return c.text('Config updated');
  })
  .post('/deploy', deployFormValidator, async (c) => {
    const { username, branch } = c.req.valid('form');

    if (deployLock) {
      pubsub.publish(
        'log',
        `${system} <span class="font-bold">${username}</span> による <span class="font-bold">${branch}</span> のデプロイは実行されませんでした (別のデプロイが進行中です)`
      );
      return c.text('Deploy in progress', 400);
    }
    deployLock = true;

    pubsub.publish(
      'log',
      `${system} <span class="font-bold">${username}</span> が <span class="font-bold">${branch}</span> のデプロイを開始しました`
    );
    const process = Bun.spawn(['bash', deployScript]);
    const reader = process.stdout.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const output = new TextDecoder().decode(value);
      const log = ansiToHtml(output.trim());
      pubsub.publish('log', log);
    }

    deployLock = false;

    if (process.exitCode !== 0) {
      pubsub.publish(
        'log',
        `${system} <span class="text-red-500"><span class="font-bold">${username}</span> による <span class="font-bold">${branch}</span> のデプロイに失敗しました</span>`
      );
      return c.text('Deploy failed', 500);
    }
    pubsub.publish(
      'log',
      `${system} <span class="text-green-500"><span class="font-bold">${username}</span> による <span class="font-bold">${branch}</span> のデプロイが完了しました</span>`
    );
    return c.text('Deploy succeeded');
  })
  .get(
    '/ws',
    upgradeWebSocket(() => ({
      onOpen(_, ws) {
        pubsub.subscribe(ws);
      },
      onClose(_, ws) {
        pubsub.unsubscribe(ws);
      },
    }))
  );

export default {
  fetch: app.fetch,
  port: 9001,
  websocket,
};
