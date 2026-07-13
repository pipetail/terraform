import { AWS_ACCOUNT_NAME, THRESHOLDS_URL } from "../config.mjs";
import { postToSlack, logSlackForward, severityFromColor } from "../slack.mjs";

function thresholdsContextBlock() {
  if (!THRESHOLDS_URL) return [];
  return [
    {
      type: "context",
      elements: [{ type: "mrkdwn", text: `<${THRESHOLDS_URL}|Modify alert thresholds>` }],
    },
  ];
}

const EVENT_CATEGORIES = {
  failover: { emoji: ":rotating_light:", color: "danger" },
  failure: { emoji: ":x:", color: "danger" },
  maintenance: { emoji: ":wrench:", color: "warning" },
  backup: { emoji: ":floppy_disk:", color: "good" },
  recovery: { emoji: ":white_check_mark:", color: "good" },
  notification: { emoji: ":bell:", color: "#439FE0" },
  default: { emoji: ":database:", color: "#439FE0" },
};

export async function handleSnsEvent(event) {
  const snsRecord = event.Records[0].Sns;
  const snsSubject = snsRecord.Subject;
  const snsBody = snsRecord.Message;

  let snsMessage;
  try {
    snsMessage = JSON.parse(snsBody);
  } catch {
    snsMessage = parseBudgetText(snsBody);
  }

  if (snsMessage["Event Source"] === "db" || snsMessage["Event Message"]) {
    const message = formatRdsAlert(snsMessage);
    await postToSlack(message);
    logSlackForward({
      category: "database",
      severity: severityFromColor(message.attachments?.[0]?.color),
      title: message.text,
    });
    return { statusCode: 200, body: "OK" };
  }

  const message = formatBudgetMessage(snsMessage, snsSubject);
  await postToSlack(message);
  logSlackForward({
    category: snsCategory(snsRecord.TopicArn),
    severity: severityFromColor(message.attachments?.[0]?.color),
    title: message.text,
  });
  return { statusCode: 200, body: "OK" };
}

function snsCategory(topicArn = "") {
  if (topicArn.includes("db-monitoring")) return "database";
  if (topicArn.includes("error-alerts")) return "ops";
  return "cost";
}

function parseBudgetText(text) {
  const get = (pattern) => {
    const m = text.match(pattern);
    return m ? m[1].trim() : undefined;
  };

  const accountId = get(/AWS Account (\d+)/);
  const budgetName = get(/Budget Name:\s*(.+)/);
  const budgetType = get(/Budget Type:\s*(.+)/);
  const limitStr = get(/Budgeted Amount:\s*\$?([\d,.]+)/);
  const actualStr = get(/ACTUAL Amount:\s*\$?([\d,.]+)/);
  const thresholdStr = get(/Alert Threshold:\s*>\s*\$?([\d,.]+)/);

  return {
    accountId,
    budgetName,
    budgetType: budgetType?.toUpperCase(),
    budgetLimit: limitStr ? { amount: limitStr.replace(/,/g, ""), unit: "USD" } : undefined,
    actualAmount: actualStr ? { amount: actualStr.replace(/,/g, ""), unit: "USD" } : undefined,
    thresholdAmount: thresholdStr ? { amount: thresholdStr.replace(/,/g, ""), unit: "USD" } : undefined,
  };
}

function formatBudgetMessage(data, subject) {
  if (subject?.includes("Budget") || data.budgetName) {
    return formatBudgetAlert(data);
  }

  if (data.anomalyId || subject?.includes("Anomaly")) {
    return formatAnomalyAlert(data);
  }

  const accountId = data.accountId || process.env.AWS_ACCOUNT_ID || "Unknown";
  const accountDisplay = AWS_ACCOUNT_NAME ? `${AWS_ACCOUNT_NAME} (${accountId})` : accountId;

  return {
    username: "AWS Budget Alerts",
    icon_emoji: ":money_with_wings:",
    text: `:warning: AWS Cost Alert`,
    attachments: [
      {
        color: "#ECB22E",
        blocks: [
          {
            type: "header",
            text: {
              type: "plain_text",
              text: `:warning: AWS Cost Alert`,
              emoji: true,
            },
          },
          {
            type: "section",
            fields: [
              { type: "mrkdwn", text: `*Account:*\n${accountDisplay}` },
            ],
          },
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: `\`\`\`${JSON.stringify(data, null, 2)}\`\`\``,
            },
          },
          ...thresholdsContextBlock(),
        ],
      },
    ],
  };
}

function getBudgetColor(data) {
  const actualAmount = parseFloat(data.actualAmount?.amount);
  const limitAmount = parseFloat(data.budgetLimit?.amount);
  const thresholdAmount = parseFloat(data.thresholdAmount?.amount);

  if (!isNaN(actualAmount) && !isNaN(limitAmount) && actualAmount >= limitAmount) {
    return "#E01E5A";
  }
  if (!isNaN(actualAmount) && !isNaN(thresholdAmount) && actualAmount >= thresholdAmount) {
    return "#ECB22E";
  }
  return "#2EB67D";
}

function formatBudgetAlert(data) {
  const budgetName = data.budgetName || "Unknown Budget";
  const budgetType = data.budgetType || "COST";
  const limit = data.budgetLimit?.amount
    ? `${data.budgetLimit.amount} ${data.budgetLimit.unit}`
    : "N/A";
  const actual = data.actualAmount?.amount
    ? `${parseFloat(data.actualAmount.amount).toFixed(2)} ${data.actualAmount.unit}`
    : "N/A";
  const forecasted = data.forecastedAmount?.amount
    ? `${parseFloat(data.forecastedAmount.amount).toFixed(2)} ${data.forecastedAmount.unit}`
    : "N/A";
  const threshold = data.thresholdAmount?.amount
    ? `${parseFloat(data.thresholdAmount.amount).toFixed(2)} ${data.thresholdAmount.unit}`
    : "N/A";
  const accountId = data.accountId || process.env.AWS_ACCOUNT_ID || "Unknown";
  const accountDisplay = AWS_ACCOUNT_NAME ? `${AWS_ACCOUNT_NAME} (${accountId})` : accountId;

  const blocks = [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: `:moneybag: AWS Budget Alert`,
        emoji: true,
      },
    },
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: [
          `*Account:* ${accountDisplay}`,
          `*Budget:* ${budgetName}`,
          `*Type:* ${budgetType}`,
          `*Limit:* ${limit}`,
          `*Actual:* ${actual}`,
          `*Forecasted:* ${forecasted}`,
          `*Threshold:* ${threshold}`,
        ].join("\n"),
      },
    },
    ...thresholdsContextBlock(),
  ];

  return {
    username: "AWS Budget Alerts",
    icon_emoji: ":money_with_wings:",
    text: `:moneybag: Budget Alert: ${budgetName}`,
    attachments: [
      {
        color: getBudgetColor(data),
        blocks,
      },
    ],
  };
}

function formatAnomalyAlert(data) {
  const anomalyId = data.anomalyId || "Unknown";
  const monitorName = data.monitorName || data.monitorArn?.split("/").pop() || "Unknown";
  const totalImpact = data.impact?.totalImpact
    ? `$${parseFloat(data.impact.totalImpact).toFixed(2)}`
    : "N/A";
  const totalActualSpend = data.impact?.totalActualSpend
    ? `$${parseFloat(data.impact.totalActualSpend).toFixed(2)}`
    : "N/A";
  const totalExpectedSpend = data.impact?.totalExpectedSpend
    ? `$${parseFloat(data.impact.totalExpectedSpend).toFixed(2)}`
    : "N/A";
  const startDate = data.anomalyStartDate || "N/A";
  const endDate = data.anomalyEndDate || "Ongoing";
  const accountId = data.accountId || process.env.AWS_ACCOUNT_ID || "Unknown";
  const accountDisplay = AWS_ACCOUNT_NAME ? `${AWS_ACCOUNT_NAME} (${accountId})` : accountId;

  const rootCauses = data.rootCauses || [];
  let rootCauseText = "";
  if (rootCauses.length > 0) {
    rootCauseText = rootCauses
      .slice(0, 3)
      .map((rc) => {
        const service = rc.service || "Unknown";
        const region = rc.region || "Unknown";
        const usageType = rc.usageType || "Unknown";
        return `- ${service} (${region}): ${usageType}`;
      })
      .join("\n");
  }

  const blocks = [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: `:chart_with_upwards_trend: AWS Cost Anomaly Detected`,
        emoji: true,
      },
    },
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: [
          `*Account:* ${accountDisplay}`,
          `*Monitor:* ${monitorName}`,
          `*Anomaly ID:* ${anomalyId.slice(-8)}`,
          `*Impact:* ${totalImpact}`,
          `*Actual Spend:* ${totalActualSpend}`,
          `*Expected Spend:* ${totalExpectedSpend}`,
          `*Period:* ${startDate} - ${endDate}`,
        ].join("\n"),
      },
    },
  ];

  if (rootCauseText) {
    blocks.push({
      type: "section",
      text: {
        type: "mrkdwn",
        text: `*Root Causes:*\n${rootCauseText}`,
      },
    });
  }

  return {
    username: "AWS Budget Alerts",
    icon_emoji: ":money_with_wings:",
    text: `:chart_with_upwards_trend: Cost Anomaly: ${monitorName} - Impact: ${totalImpact}`,
    attachments: [
      {
        color: "#E01E5A",
        blocks,
      },
    ],
  };
}

function extractRegionFromArn(arn) {
  if (!arn) return null;
  const parts = arn.split(":");
  return parts.length >= 4 ? parts[3] : null;
}

function extractAccountIdFromArn(arn) {
  if (!arn) return null;
  const parts = arn.split(":");
  return parts.length >= 5 ? parts[4] : null;
}

function getEventCategory(eventMessage) {
  const message = (eventMessage || "").toLowerCase();

  if (message.includes("failover") || message.includes("failed over")) {
    return EVENT_CATEGORIES.failover;
  }
  if (message.includes("failure") || message.includes("failed") || message.includes("error")) {
    return EVENT_CATEGORIES.failure;
  }
  if (message.includes("maintenance") || message.includes("patching") || message.includes("upgrade")) {
    return EVENT_CATEGORIES.maintenance;
  }
  if (message.includes("backup") || message.includes("snapshot")) {
    return EVENT_CATEGORIES.backup;
  }
  if (message.includes("recovery") || message.includes("recovered") || message.includes("restored")) {
    return EVENT_CATEGORIES.recovery;
  }
  if (message.includes("notification") || message.includes("started") || message.includes("completed")) {
    return EVENT_CATEGORIES.notification;
  }

  return EVENT_CATEGORIES.default;
}

function formatRdsAlert(rdsEvent) {
  const eventMessage = rdsEvent["Event Message"] || "Unknown event";
  const sourceId = rdsEvent["Source ID"] || "Unknown";
  const sourceArn = rdsEvent["Source ARN"] || "";
  const eventTime = rdsEvent["Event Time"] || new Date().toISOString();
  const identifierLink = rdsEvent["Identifier Link"] || "";

  const region = extractRegionFromArn(sourceArn);
  const accountId = extractAccountIdFromArn(sourceArn) || "Unknown";
  const category = getEventCategory(eventMessage);

  const fields = [
    { type: "mrkdwn", text: `*Database:*\n\`${sourceId}\`` },
  ];

  if (region) {
    fields.push({ type: "mrkdwn", text: `*Region:*\n${region}` });
  }

  fields.push({ type: "mrkdwn", text: `*Time:*\n${eventTime}` });

  if (identifierLink) {
    fields.push({ type: "mrkdwn", text: `*Console:*\n<${identifierLink}|View in AWS>` });
  }

  const blocks = [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: `${category.emoji} RDS Event`,
        emoji: true,
      },
    },
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: `*${eventMessage}*`,
      },
    },
    {
      type: "section",
      fields,
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: `Account: ${AWS_ACCOUNT_NAME ? `${AWS_ACCOUNT_NAME} (${accountId})` : accountId}`,
        },
      ],
    },
  ];

  return {
    text: `${category.emoji} RDS Event: ${eventMessage}`,
    attachments: [
      {
        color: category.color,
        blocks,
      },
    ],
  };
}
