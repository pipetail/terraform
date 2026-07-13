import https from "https";
import { SLACK_WEBHOOK_URL, SLACK_BOT_TOKEN, SLACK_CHANNEL } from "./config.mjs";

function postViaBotToken(message) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ channel: SLACK_CHANNEL, ...message });

    const options = {
      hostname: "slack.com",
      port: 443,
      path: "/api/chat.postMessage",
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Bearer ${SLACK_BOT_TOKEN}`,
        "Content-Length": Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        console.log(`Slack API response: ${res.statusCode} - ${data}`);
        try {
          const parsed = JSON.parse(data);
          if (parsed.ok) {
            resolve(parsed);
          } else {
            reject(new Error(`Slack API error: ${parsed.error}`));
          }
        } catch (e) {
          reject(new Error(`Slack API parse error: ${data}`));
        }
      });
    });

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function postViaWebhook(message) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(message);
    const url = new URL(SLACK_WEBHOOK_URL);

    const options = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let body = "";
      res.on("data", (chunk) => (body += chunk));
      res.on("end", () => {
        console.log(`Slack response: ${res.statusCode} - ${body}`);
        if (res.statusCode === 200) {
          resolve(body);
        } else {
          reject(new Error(`Slack API error: ${res.statusCode} - ${body}`));
        }
      });
    });

    req.on("error", reject);
    req.write(postData);
    req.end();
  });
}

export function postToSlack(message) {
  if (SLACK_BOT_TOKEN && SLACK_CHANNEL) {
    return postViaBotToken(message);
  }
  return postViaWebhook(message);
}

const COLOR_SEVERITY = { danger: "high", warning: "medium", good: "low" };

export function severityFromColor(color) {
  return COLOR_SEVERITY[color] || "medium";
}

// Structured line parsed by the pipetail.cloud portal to build a timeline of
// forwarded events — emit exactly once after each successful postToSlack.
export function logSlackForward({ category, severity, title }) {
  console.log(JSON.stringify({ evt: "slack_forward", ts: new Date().toISOString(), category, severity, title }));
}
