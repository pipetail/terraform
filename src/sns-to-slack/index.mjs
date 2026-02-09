import https from "https";

const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;

function postToSlack(message) {
  return new Promise((resolve, reject) => {
    const url = new URL(SLACK_WEBHOOK_URL);
    const payload = JSON.stringify(message);

    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      let body = "";
      res.on("data", (chunk) => (body += chunk));
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(body);
        } else {
          reject(new Error(`Slack returned ${res.statusCode}: ${body}`));
        }
      });
    });

    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

function formatSnsMessage(record) {
  const sns = record.Sns;
  const subject = sns.Subject || "SNS Notification";
  const message = sns.Message;
  const topicArn = sns.TopicArn;
  const topicName = topicArn.split(":").pop();
  const timestamp = sns.Timestamp;

  return {
    blocks: [
      {
        type: "header",
        text: { type: "plain_text", text: subject },
      },
      {
        type: "section",
        text: { type: "mrkdwn", text: `\`\`\`${message}\`\`\`` },
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: `*Topic:* ${topicName} | *Time:* ${timestamp}`,
          },
        ],
      },
    ],
  };
}

export const handler = async (event) => {
  if (!SLACK_WEBHOOK_URL) {
    throw new Error("SLACK_WEBHOOK_URL environment variable is not set");
  }

  for (const record of event.Records) {
    const message = formatSnsMessage(record);
    await postToSlack(message);
    console.log(`Forwarded SNS message: ${record.Sns.Subject || record.Sns.MessageId}`);
  }

  return { statusCode: 200, body: "OK" };
};
