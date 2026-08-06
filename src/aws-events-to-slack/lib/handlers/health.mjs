import { AWS_ACCOUNT_NAME } from "../config.mjs";
import { postToSlack, logSlackForward, severityFromColor, truncate, SLACK_TEXT_LIMIT } from "../slack.mjs";

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

  let header = `:hospital: *AWS Health Event*\n\n`;
  header += `*Service:* ${service}\n`;
  header += `*Event:* ${eventTypeCode}\n`;
  header += `*Region:* ${region}\n`;
  header += `*Status:* ${statusCode}\n`;
  header += `*Started:* ${startTime}\n`;
  header += `\n*Description:*\n`;

  let footer = "";

  if (affectedEntities.length > 0) {
    footer += `\n\n*Affected Resources:*\n`;
    for (const entity of affectedEntities) {
      footer += `- \`${entity}\`\n`;
    }
  }

  footer += `\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  // AWS writes descriptions long enough to blow the block limit by themselves.
  // Spend what's left of the budget on the description so the affected
  // resources and account survive instead of being cut off the end.
  const budget = SLACK_TEXT_LIMIT - header.length - footer.length;
  const text = header + truncate(description, budget) + footer;

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
