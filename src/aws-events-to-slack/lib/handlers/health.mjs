import { AWS_ACCOUNT_NAME } from "../config.mjs";
import { postToSlack, logSlackForward, severityFromColor } from "../slack.mjs";

// Events that are noise when they close successfully
const SKIP_WHEN_CLOSED = new Set([
  "AWS_ACM_RENEWAL_STATE_CHANGE",
]);

export async function handleHealthEvent(event) {
  const detail = event.detail || {};
  const service = detail.service || "Unknown";
  const eventTypeCode = detail.eventTypeCode || "Unknown";
  const region = event.region || "Unknown";
  const startTime = detail.startTime || event.time || new Date().toISOString();
  const statusCode = detail.statusCode || "Unknown";

  if (statusCode === "closed" && SKIP_WHEN_CLOSED.has(eventTypeCode)) {
    console.log(`Skipping ${eventTypeCode} with status closed`);
    return { statusCode: 200, body: "Skipped" };
  }

  const rawDescription = detail.eventDescription?.[0]?.latestDescription || "No description available";
  const description = rawDescription.replace(/\\n/g, "\n").trim();

  const affectedEntities = (detail.affectedEntities || [])
    .map((e) => e.entityValue)
    .filter(Boolean)
    .slice(0, 10);

  let text = `:hospital: *AWS Health Event*\n\n`;
  text += `*Service:* ${service}\n`;
  text += `*Event:* ${eventTypeCode}\n`;
  text += `*Region:* ${region}\n`;
  text += `*Status:* ${statusCode}\n`;
  text += `*Started:* ${startTime}\n`;
  text += `\n*Description:*\n${description}`;

  if (affectedEntities.length > 0) {
    text += `\n\n*Affected Resources:*\n`;
    for (const entity of affectedEntities) {
      text += `- \`${entity}\`\n`;
    }
  }

  text += `\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  const color = statusCode === "closed" ? "good" : "danger";
  const summary = `:hospital: AWS Health: ${service} - ${eventTypeCode}`;

  await postToSlack({
    text: summary,
    attachments: [
      {
        color,
        blocks: [
          {
            type: "section",
            text: { type: "mrkdwn", text },
          },
        ],
      },
    ],
  });

  let logBody = `${service} ${eventTypeCode} (${statusCode}) in ${region}: ${description.replace(/\s+/g, " ").slice(0, 300)}`;
  if (affectedEntities.length > 0) {
    logBody += ` — affected: ${affectedEntities.join(", ")}`;
  }

  logSlackForward({ category: "health", severity: severityFromColor(color), title: summary, body: logBody });

  return { statusCode: 200, body: "OK" };
}
