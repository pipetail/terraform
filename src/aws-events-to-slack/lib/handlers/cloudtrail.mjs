import { AWS_ACCOUNT_NAME } from "../config.mjs";
import { postToSlack, logSlackForward, severityFromColor } from "../slack.mjs";

const IGNORED_EVENTS = new Set(
  (process.env.CLOUDTRAIL_IGNORED_EVENTS || "")
    .split(",")
    .map((e) => e.trim())
    .filter(Boolean),
);

const DESTRUCTIVE_EVENTS = new Set([
  "DeleteTrail",
  "StopLogging",
  "DeleteUser",
  "DeleteRole",
  "DeleteAccessKey",
  "StopInstances",
  "TerminateInstances",
]);

export async function handleCloudTrailEvent(event) {
  const detailType = event["detail-type"];

  const eventName = event.detail?.eventName || "ConsoleLogin";

  if (IGNORED_EVENTS.has(eventName)) {
    console.log(`CloudTrail event ${eventName} is in ignore list, skipping`);
    return { statusCode: 200, body: "Ignored event" };
  }

  if (detailType === "AWS Console Sign In via CloudTrail") {
    return handleConsoleLogin(event, event.detail);
  }

  return handleApiCall(event, event.detail);
}

async function handleApiCall(event, detail) {
  const eventName = detail.eventName || "Unknown";
  const userIdentity = detail.userIdentity || {};
  const who =
    userIdentity.userName ||
    userIdentity.arn ||
    userIdentity.principalId ||
    "Unknown";
  const userType = userIdentity.type || "Unknown";
  const sourceIP = detail.sourceIPAddress || "Unknown";
  const region = event.region || detail.awsRegion || "Unknown";
  const eventTime = detail.eventTime || event.time || new Date().toISOString();
  const errorCode = detail.errorCode;
  const errorMessage = detail.errorMessage;

  const requestParams = detail.requestParameters
    ? JSON.stringify(detail.requestParameters, null, 2).slice(0, 500)
    : "N/A";

  const color = DESTRUCTIVE_EVENTS.has(eventName) ? "danger" : "warning";

  let text = `:shield: *CloudTrail: ${eventName}*\n\n`;
  text += `*Who:* ${who} (${userType})\n`;
  text += `*What:* \`${eventName}\`\n`;
  text += `*Where:* ${region}\n`;
  text += `*When:* ${eventTime}\n`;
  text += `*Source IP:* ${sourceIP}\n`;
  text += `*Request Parameters:*\n\`\`\`${requestParams}\`\`\``;

  if (errorCode) {
    text += `\n:x: *Error:* ${errorCode} - ${errorMessage || ""}`;
  }

  text += `\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  const summary = `:shield: CloudTrail: ${eventName} by ${who}`;

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

  let logBody = `${who} (${userType}) called ${eventName} in ${region} at ${eventTime} from ${sourceIP}`;
  if (errorCode) {
    logBody += ` — error ${errorCode}${errorMessage ? `: ${errorMessage}` : ""}`;
  }

  logSlackForward({ category: "security", severity: severityFromColor(color), title: summary, body: logBody });

  return { statusCode: 200, body: "OK" };
}

async function handleConsoleLogin(event, detail) {
  const userIdentity = detail.userIdentity || {};
  const userType = userIdentity.type || "Unknown";
  const isRoot = userType === "Root";
  const mfaUsed = detail.additionalEventData?.MFAUsed === "Yes";

  if (!isRoot && mfaUsed) {
    console.log("Normal MFA login, skipping notification");
    return { statusCode: 200, body: "Normal login, skipped" };
  }

  const who = userIdentity.userName || userIdentity.arn || userType;
  const sourceIP = detail.sourceIPAddress || "Unknown";
  const eventTime = detail.eventTime || event.time || new Date().toISOString();
  const loginResult = detail.responseElements?.ConsoleLogin || "Unknown";

  let reason = "";
  if (isRoot) reason = ":rotating_light: Root account login";
  else if (!mfaUsed) reason = ":warning: Login without MFA";

  let text = `${reason}\n\n`;
  text += `*Who:* ${who} (${userType})\n`;
  text += `*Result:* ${loginResult}\n`;
  text += `*MFA:* ${mfaUsed ? "Yes" : "No"}\n`;
  text += `*Source IP:* ${sourceIP}\n`;
  text += `*When:* ${eventTime}\n`;
  text += `\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  const color = isRoot ? "danger" : "warning";
  const summary = `${reason} — ${who}`;

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

  const plainReason = isRoot ? "Root account login" : "Login without MFA";
  const logBody = `${plainReason}: ${who} (${userType}) result ${loginResult}, MFA ${mfaUsed ? "yes" : "no"}, from ${sourceIP} at ${eventTime}`;

  logSlackForward({ category: "security", severity: severityFromColor(color), title: summary, body: logBody });

  return { statusCode: 200, body: "OK" };
}
