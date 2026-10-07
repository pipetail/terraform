import { after, before, beforeEach, describe, it, mock } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import https from "node:https";

// config.mjs reads the environment once at import time, so it has to be set
// before the handler module is loaded.
process.env.SLACK_WEBHOOK_URL = "https://hooks.slack.example/services/T000/B000/XXXX";
process.env.AWS_ACCOUNT_NAME = "example-account";
process.env.THRESHOLDS_URL = "https://example.com/thresholds";
delete process.env.SLACK_BOT_TOKEN;
delete process.env.SLACK_CHANNEL;

const { handleSnsEvent } = await import("../../src/aws-events-to-slack/lib/handlers/sns.mjs");

const TOPIC_ARN = "arn:aws:sns:eu-west-1:123456789012:example-topic";
const THRESHOLDS_CONTEXT = {
  type: "context",
  elements: [{ type: "mrkdwn", text: "<https://example.com/thresholds|Modify alert thresholds>" }],
};

let posted;
let forwards;

before(() => {
  mock.method(https, "request", (options, callback) => {
    const req = new EventEmitter();
    let body = "";
    req.write = (chunk) => {
      body += chunk;
    };
    req.end = () => {
      posted.push(JSON.parse(body));
      const res = new EventEmitter();
      res.statusCode = 200;
      callback(res);
      res.emit("data", "ok");
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
  posted = [];
  forwards = [];
});

function snsEvent(message, { subject = null, topicArn = TOPIC_ARN } = {}) {
  return {
    Records: [
      {
        EventSource: "aws:sns",
        Sns: {
          Type: "Notification",
          TopicArn: topicArn,
          Subject: subject,
          Message: typeof message === "string" ? message : JSON.stringify(message),
        },
      },
    ],
  };
}

async function send(message, options) {
  const result = await handleSnsEvent(snsEvent(message, options));
  assert.deepEqual(result, { statusCode: 200, body: "OK" });
  assert.equal(posted.length, 1);
  assert.equal(forwards.length, 1);
  return { message: posted[0], forward: forwards[0] };
}

function alarm(overrides = {}) {
  return {
    AlarmName: "example-heartbeat",
    AlarmDescription: "Heartbeat from the example service stopped arriving.",
    AWSAccountId: "123456789012",
    AlarmConfigurationUpdatedTimestamp: "2026-09-01T08:00:00.000+0000",
    NewStateValue: "ALARM",
    NewStateReason:
      "Threshold Crossed: 1 out of the last 1 datapoints [0.0 (25/09/26 10:00:00)] was less than the threshold (1.0) (minimum 1 datapoint for OK -> ALARM transition).",
    StateChangeTime: "2026-09-25T10:05:00.000+0000",
    Region: "EU (Ireland)",
    AlarmArn: "arn:aws:cloudwatch:eu-west-1:123456789012:alarm:example-heartbeat",
    OldStateValue: "OK",
    OKActions: [TOPIC_ARN],
    AlarmActions: [TOPIC_ARN],
    InsufficientDataActions: [],
    Trigger: {
      MetricName: "Heartbeat",
      Namespace: "Example",
      StatisticType: "Statistic",
      Statistic: "SUM",
      Unit: null,
      Dimensions: [],
      Period: 300,
      EvaluationPeriods: 1,
      ComparisonOperator: "LessThanThreshold",
      Threshold: 1.0,
      TreatMissingData: "breaching",
      EvaluateLowSampleCountPercentile: "",
    },
    ...overrides,
  };
}

function header(message) {
  return message.attachments[0].blocks[0].text.text;
}

function hasThresholdsLink(message) {
  return JSON.stringify(message).includes("Modify alert thresholds");
}

describe("CloudWatch alarm notifications", () => {
  it("formats ALARM as a red alert", async () => {
    const { message, forward } = await send(alarm(), {
      subject: 'ALARM: "example-heartbeat" in EU (Ireland)',
    });

    assert.deepEqual(message, {
      attachments: [
        {
          color: "danger",
          fallback: ":rotating_light: CloudWatch Alarm: example-heartbeat in ALARM",
          blocks: [
            {
              type: "header",
              text: { type: "plain_text", text: ":rotating_light: example-heartbeat in ALARM", emoji: true },
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: "*Description:*\nHeartbeat from the example service stopped arriving.",
              },
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: "*Reason:*\nThreshold Crossed: 1 out of the last 1 datapoints [0.0 (25/09/26 10:00:00)] was less than the threshold (1.0) (minimum 1 datapoint for OK -> ALARM transition).",
              },
            },
            {
              type: "section",
              fields: [
                { type: "mrkdwn", text: "*State:*\nOK → ALARM" },
                { type: "mrkdwn", text: "*Region:*\neu-west-1" },
                { type: "mrkdwn", text: "*Time:*\n2026-09-25T10:05:00.000+0000" },
              ],
            },
            {
              type: "context",
              elements: [{ type: "mrkdwn", text: "Account: example-account (123456789012)" }],
            },
          ],
        },
      ],
    });

    assert.equal(forward.evt, "slack_forward");
    assert.equal(forward.category, "ops");
    assert.equal(forward.severity, "high");
    assert.equal(forward.title, message.attachments[0].fallback);
    assert.match(forward.body, /^example-heartbeat OK -> ALARM in eu-west-1 at 2026-09-25T10:05:00\.000\+0000: Threshold Crossed/);
  });

  it("formats OK as a green recovery", async () => {
    const { message, forward } = await send(
      alarm({
        NewStateValue: "OK",
        OldStateValue: "ALARM",
        NewStateReason: "Threshold Crossed: 1 datapoint [3.0 (25/09/26 10:10:00)] was not less than the threshold (1.0).",
      })
    );

    assert.equal(message.attachments[0].color, "good");
    assert.equal(message.attachments[0].fallback, ":white_check_mark: CloudWatch Alarm: example-heartbeat recovered (OK)");
    assert.equal(header(message), ":white_check_mark: example-heartbeat recovered (OK)");
    assert.ok(JSON.stringify(message).includes("*State:*\\nALARM → OK"));
    assert.equal(hasThresholdsLink(message), false);
    assert.equal(forward.severity, "low");
    assert.equal(forward.category, "ops");
  });

  it("formats INSUFFICIENT_DATA as a grey notice", async () => {
    const { message, forward } = await send(
      alarm({
        NewStateValue: "INSUFFICIENT_DATA",
        NewStateReason: "Insufficient Data: 1 datapoint was unknown.",
      })
    );

    assert.equal(message.attachments[0].color, "#9E9E9E");
    assert.equal(header(message), ":grey_question: example-heartbeat has INSUFFICIENT_DATA");
    assert.equal(hasThresholdsLink(message), false);
    assert.equal(forward.severity, "medium");
  });

  it("omits a missing description and keeps the header within Slack's limit", async () => {
    const { message } = await send(alarm({ AlarmName: "x".repeat(255), AlarmDescription: null }));

    const blocks = message.attachments[0].blocks;
    assert.ok(header(message).length <= 150);
    assert.match(header(message), /^:rotating_light: x+…$/);
    assert.equal(
      blocks.some((block) => block.text?.text?.startsWith("*Description:*")),
      false
    );
  });

  it("keeps the database category for alarms on a database topic", async () => {
    const { forward } = await send(alarm(), {
      topicArn: "arn:aws:sns:eu-west-1:123456789012:example-db-monitoring",
    });

    assert.equal(forward.category, "database");
  });
});

function guardDutyEvent(detailOverrides = {}) {
  return {
    version: "0",
    id: "11111111-2222-3333-4444-555555555555",
    "detail-type": "GuardDuty Finding",
    source: "aws.guardduty",
    account: "123456789012",
    time: "2026-10-07T09:00:00Z",
    region: "eu-west-1",
    resources: [],
    detail: {
      schemaVersion: "2.0",
      accountId: "123456789012",
      region: "eu-west-1",
      partition: "aws",
      id: "abc123finding",
      arn: "arn:aws:guardduty:eu-west-1:123456789012:detector/det1/finding/abc123finding",
      type: "UnauthorizedAccess:EC2/SSHBruteForce",
      resource: {
        resourceType: "Instance",
        instanceDetails: { instanceId: "i-0123456789abcdef0" },
      },
      service: { serviceName: "guardduty", count: 3, additionalInfo: {} },
      severity: 5,
      createdAt: "2026-10-07T08:55:00.000Z",
      updatedAt: "2026-10-07T09:00:00.000Z",
      title: "198.51.100.7 is performing SSH brute force attacks against i-0123456789abcdef0.",
      description: "198.51.100.7 is performing SSH brute force attacks against i-0123456789abcdef0. Brute force attacks are used to gain unauthorized access to your instance by guessing the SSH password.",
      ...detailOverrides,
    },
  };
}

describe("GuardDuty findings", () => {
  it("formats a medium finding with type, resource, Region and console link", async () => {
    const { message, forward } = await send(guardDutyEvent());

    assert.deepEqual(message, {
      attachments: [
        {
          color: "warning",
          fallback: ":warning: GuardDuty Medium: UnauthorizedAccess:EC2/SSHBruteForce",
          blocks: [
            {
              type: "header",
              text: {
                type: "plain_text",
                text: ":warning: GuardDuty: 198.51.100.7 is performing SSH brute force attacks against i-0123456789abcdef0.",
                emoji: true,
              },
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: "198.51.100.7 is performing SSH brute force attacks against i-0123456789abcdef0. Brute force attacks are used to gain unauthorized access to your instance by guessing the SSH password.",
              },
            },
            {
              type: "section",
              fields: [
                { type: "mrkdwn", text: "*Type:*\n`UnauthorizedAccess:EC2/SSHBruteForce`" },
                { type: "mrkdwn", text: "*Severity:*\nMedium (5)" },
                { type: "mrkdwn", text: "*Resource:*\nInstance i-0123456789abcdef0" },
                { type: "mrkdwn", text: "*Region:*\neu-west-1" },
                { type: "mrkdwn", text: "*Occurrences:*\n3" },
                {
                  type: "mrkdwn",
                  text: "*Console:*\n<https://eu-west-1.console.aws.amazon.com/guardduty/home?region=eu-west-1#/findings?macros=current&fId=abc123finding|View in GuardDuty>",
                },
              ],
            },
            {
              type: "context",
              elements: [{ type: "mrkdwn", text: "Account: example-account (123456789012)" }],
            },
          ],
        },
      ],
    });

    assert.equal(forward.category, "security");
    assert.equal(forward.severity, "medium");
    assert.equal(forward.title, message.attachments[0].fallback);
    assert.match(forward.body, /^UnauthorizedAccess:EC2\/SSHBruteForce \(Medium 5\) on Instance i-0123456789abcdef0 in eu-west-1: 198\.51\.100\.7/);
  });

  it("maps high and critical findings to a red alert", async () => {
    for (const [value, label] of [[7, "High"], [8.9, "High"], [9, "Critical"], [10, "Critical"]]) {
      posted = [];
      forwards = [];
      const { message, forward } = await send(guardDutyEvent({ severity: value }));
      assert.equal(message.attachments[0].color, "danger");
      assert.equal(message.attachments[0].fallback, `:rotating_light: GuardDuty ${label}: UnauthorizedAccess:EC2/SSHBruteForce`);
      assert.equal(forward.severity, "high");
    }
  });

  it("maps a low finding to a grey notice", async () => {
    const { message, forward } = await send(guardDutyEvent({ severity: 2 }));

    assert.equal(message.attachments[0].color, "#9E9E9E");
    assert.ok(JSON.stringify(message).includes("*Severity:*\\nLow (2)"));
    assert.equal(forward.severity, "medium");
  });

  it("marks sample findings so a test is not mistaken for an attack", async () => {
    const { message, forward } = await send(
      guardDutyEvent({ service: { serviceName: "guardduty", count: 1, additionalInfo: { sample: true } } })
    );

    assert.match(header(message), /^:warning: \[sample\] GuardDuty: /);
    assert.match(message.attachments[0].fallback, /\[sample\]/);
    assert.match(forward.body, /\[sample\]/);
    assert.equal(JSON.stringify(message).includes("*Occurrences:*"), false);
  });

  it("names the resource for an access key finding", async () => {
    const { message } = await send(
      guardDutyEvent({
        type: "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS",
        resource: { resourceType: "AccessKey", accessKeyDetails: { userName: "example-role", accessKeyId: "ASIAEXAMPLE" } },
      })
    );

    assert.ok(JSON.stringify(message).includes("*Resource:*\\nAccessKey example-role"));
  });

  it("keeps a long title within Slack's header limit", async () => {
    const { message } = await send(guardDutyEvent({ title: "x".repeat(400) }));

    assert.ok(header(message).length <= 150);
    assert.match(header(message), /^:warning: GuardDuty: x+…$/);
  });
});

describe("unrecognised SNS messages", () => {
  it("are shown as a neutral AWS notification, not a cost alert", async () => {
    const { message, forward } = await send({ foo: "bar" }, { subject: "Something happened" });

    assert.deepEqual(message, {
      attachments: [
        {
          color: "#9E9E9E",
          fallback: ":bell: AWS Notification",
          blocks: [
            {
              type: "header",
              text: { type: "plain_text", text: ":bell: AWS Notification", emoji: true },
            },
            {
              type: "section",
              fields: [{ type: "mrkdwn", text: "*Account:*\nexample-account (Unknown)" }],
            },
            {
              type: "section",
              text: { type: "mrkdwn", text: '```{\n  "foo": "bar"\n}```' },
            },
          ],
        },
      ],
    });
    assert.equal(forward.severity, "medium");
    assert.equal(forward.body, '{"foo":"bar"}');
  });

  it("show the subject and raw text of a plain-text message", async () => {
    const subject = "RDS Notification Message";
    const text =
      "This is a message to notify that RDS will attempt to send you event notifications of type db-instance to the topic arn:aws:sns:eu-west-1:123456789012:example-topic.";

    const { message, forward } = await send(text, { subject });

    const rendered = JSON.stringify(message);
    assert.ok(rendered.includes(subject), "subject missing from Slack message");
    assert.ok(rendered.includes(text), "raw message missing from Slack message");
    assert.equal(rendered.includes("```{}```"), false);
    assert.ok(forward.body.includes(text), "raw message missing from log body");
  });
});

describe("budget and anomaly notifications", () => {
  it("formats a plain-text budget notification unchanged", async () => {
    const text = [
      "AWS Budget Notification September 25, 2026",
      "AWS Account 123456789012",
      "",
      "Dear AWS Customer,",
      "",
      "You requested that we alert you when the ACTUAL Cost associated with your example-monthly budget is greater than $80.00 for the current month.",
      "",
      "Budget Name: example-monthly",
      "Budget Type: Cost",
      "Budgeted Amount: $100.00",
      "Alert Type: ACTUAL",
      "Alert Threshold: > $80.00",
      "ACTUAL Amount: $85.50",
    ].join("\n");

    const { message, forward } = await send(text, {
      subject: "AWS Budgets: example-monthly has exceeded your alert threshold",
    });

    assert.deepEqual(message, {
      username: "AWS Budget Alerts",
      icon_emoji: ":money_with_wings:",
      attachments: [
        {
          color: "#ECB22E",
          fallback: ":moneybag: Budget Alert: example-monthly",
          blocks: [
            {
              type: "header",
              text: { type: "plain_text", text: ":moneybag: AWS Budget Alert", emoji: true },
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: [
                  "*Account:* example-account (123456789012)",
                  "*Budget:* example-monthly",
                  "*Type:* COST",
                  "*Limit:* 100.00 USD",
                  "*Actual:* 85.50 USD",
                  "*Forecasted:* N/A",
                  "*Threshold:* 80.00 USD",
                ].join("\n"),
              },
            },
            THRESHOLDS_CONTEXT,
          ],
        },
      ],
    });
    assert.equal(forward.category, "cost");
    assert.equal(forward.severity, "medium");
    assert.equal(
      forward.body,
      "Budget example-monthly (COST): actual 85.50 USD, limit 100.00 USD, threshold 80.00 USD"
    );
  });

  it("formats a cost anomaly notification unchanged", async () => {
    const { message, forward } = await send({
      accountId: "123456789012",
      anomalyId: "a1b2c3d4-0000-1111-2222-333344445555",
      monitorName: "example-monitor",
      anomalyStartDate: "2026-09-24",
      anomalyEndDate: "2026-09-25",
      impact: { totalImpact: 42.5, totalActualSpend: 142.5, totalExpectedSpend: 100 },
      rootCauses: [{ service: "Amazon Elastic Compute Cloud - Compute", region: "eu-west-1", usageType: "BoxUsage:m7g.large" }],
    });

    assert.deepEqual(message, {
      username: "AWS Budget Alerts",
      icon_emoji: ":money_with_wings:",
      attachments: [
        {
          color: "#E01E5A",
          fallback: ":chart_with_upwards_trend: Cost Anomaly: example-monitor - Impact: $42.50",
          blocks: [
            {
              type: "header",
              text: { type: "plain_text", text: ":chart_with_upwards_trend: AWS Cost Anomaly Detected", emoji: true },
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: [
                  "*Account:* example-account (123456789012)",
                  "*Monitor:* example-monitor",
                  "*Anomaly ID:* 44445555",
                  "*Impact:* $42.50",
                  "*Actual Spend:* $142.50",
                  "*Expected Spend:* $100.00",
                  "*Period:* 2026-09-24 - 2026-09-25",
                ].join("\n"),
              },
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: "*Root Causes:*\n- Amazon Elastic Compute Cloud - Compute (eu-west-1): BoxUsage:m7g.large",
              },
            },
          ],
        },
      ],
    });
    assert.equal(forward.category, "cost");
    assert.equal(forward.severity, "medium");
  });
});
