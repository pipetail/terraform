import { after, before, beforeEach, describe, it, mock } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import https from "node:https";

// config.mjs reads the environment once at import time, so it has to be set
// before the handler modules are loaded. sns.test.mjs covers the webhook
// transport; this file posts through chat.postMessage.
process.env.SLACK_BOT_TOKEN = "xoxb-example";
process.env.SLACK_CHANNEL = "C0000EXAMPLE";
delete process.env.SLACK_WEBHOOK_URL;
process.env.AWS_ACCOUNT_NAME = "example-prod";

const { handleSnsEvent } = await import("../../src/aws-events-to-slack/lib/handlers/sns.mjs");
const { handleHealthEvent } = await import("../../src/aws-events-to-slack/lib/handlers/health.mjs");
const { handleCloudTrailEvent } = await import("../../src/aws-events-to-slack/lib/handlers/cloudtrail.mjs");

const TOPIC_ARN = "arn:aws:sns:eu-west-1:123456789012:example-topic";

let requests;
let forwards;

before(() => {
  mock.method(https, "request", (options, callback) => {
    const req = new EventEmitter();
    let body = "";
    req.write = (chunk) => {
      body += chunk;
    };
    req.end = () => {
      requests.push({ options, body: JSON.parse(body) });
      const res = new EventEmitter();
      res.statusCode = 200;
      callback(res);
      res.emit("data", '{"ok":true}');
      res.emit("end");
    };
    return req;
  });

  mock.method(console, "log", (line) => {
    if (typeof line === "string" && line.startsWith('{"evt":"slack_forward"')) {
      forwards.push(JSON.parse(line));
    }
  });
});

after(() => mock.restoreAll());

beforeEach(() => {
  requests = [];
  forwards = [];
});

function sns(message, subject = null) {
  return handleSnsEvent({
    Records: [
      {
        EventSource: "aws:sns",
        Sns: {
          Type: "Notification",
          TopicArn: TOPIC_ARN,
          Subject: subject,
          Message: typeof message === "string" ? message : JSON.stringify(message),
        },
      },
    ],
  });
}

const CARDS = {
  "RDS event": ["database", () =>
    sns({
      "Event Source": "db-instance",
      "Event Time": "2026-09-25 10:00:00.000",
      "Identifier Link": "https://console.aws.amazon.com/rds/home?region=eu-west-1#dbinstance:id=app-db",
      "Source ID": "app-db",
      "Source ARN": "arn:aws:rds:eu-west-1:123456789012:db:app-db",
      "Event ID": "http://docs.amazonwebservices.com/AmazonRDS/latest/UserGuide/USER_Events.html#RDS-EVENT-0049",
      "Event Message": "Multi-AZ instance failover completed",
    })],
  "CloudWatch alarm": ["ops", () =>
    sns({
      AlarmName: "example-heartbeat",
      NewStateValue: "ALARM",
      OldStateValue: "OK",
      NewStateReason: "Threshold Crossed",
      StateChangeTime: "2026-09-25T10:05:00.000+0000",
      AlarmArn: "arn:aws:cloudwatch:eu-west-1:123456789012:alarm:example-heartbeat",
    })],
  "budget alert": ["cost", () =>
    sns(
      {
        accountId: "123456789012",
        budgetName: "example-monthly",
        budgetLimit: { amount: "100", unit: "USD" },
        actualAmount: { amount: "85.5", unit: "USD" },
      },
      "AWS Budgets: example-monthly has exceeded your alert threshold"
    )],
  "cost anomaly": ["cost", () =>
    sns({
      accountId: "123456789012",
      anomalyId: "a1b2c3d4-0000-1111-2222-333344445555",
      monitorName: "example-monitor",
      impact: { totalImpact: 42.5, totalActualSpend: 142.5, totalExpectedSpend: 100 },
    })],
  "generic notification": ["cost", () => sns({ foo: "bar" }, "Something happened")],
  "plain-text notification": ["cost", () =>
    sns("RDS will send event notifications of type db-instance to this topic.", "RDS Notification Message")],
  "AWS Health event": ["health", () =>
    handleHealthEvent({
      source: "aws.health",
      region: "eu-west-1",
      detail: {
        service: "EC2",
        eventTypeCode: "AWS_EC2_OPERATIONAL_ISSUE",
        statusCode: "open",
        eventDescription: [{ latestDescription: "Increased API error rates." }],
      },
    })],
  "CloudTrail API call": ["security", () =>
    handleCloudTrailEvent({
      "detail-type": "AWS API Call via CloudTrail",
      region: "eu-west-1",
      detail: {
        eventName: "DeleteUser",
        userIdentity: { type: "IAMUser", userName: "example-user" },
        sourceIPAddress: "192.0.2.10",
      },
    })],
  "console login": ["security", () =>
    handleCloudTrailEvent({
      "detail-type": "AWS Console Sign In via CloudTrail",
      detail: {
        userIdentity: { type: "Root" },
        additionalEventData: { MFAUsed: "No" },
        responseElements: { ConsoleLogin: "Success" },
        sourceIPAddress: "192.0.2.10",
      },
    })],
};

describe("alert cards show their title once", () => {
  for (const [name, [category, fire]] of Object.entries(CARDS)) {
    it(name, async () => {
      await fire();

      assert.equal(requests.length, 1);
      assert.equal(forwards.length, 1);
      assert.equal(forwards[0].category, category);
      const { options, body } = requests[0];
      assert.equal(options.path, "/api/chat.postMessage");
      assert.equal(body.channel, "C0000EXAMPLE");

      assert.equal(Object.hasOwn(body, "text"), false, "card sets a top-level text");
      assert.ok(body.attachments.length > 0);
      for (const attachment of body.attachments) {
        assert.equal(typeof attachment.fallback, "string");
        assert.notEqual(attachment.fallback.trim(), "");
        assert.ok(attachment.blocks.length > 0);
      }

      assert.equal(typeof forwards[0].title, "string");
      assert.notEqual(forwards[0].title.trim(), "");
      assert.equal(forwards[0].title, body.attachments[0].fallback);
    });
  }
});
