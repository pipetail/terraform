import { after, before, beforeEach, describe, it, mock } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import https from "node:https";
import { registerHooks } from "node:module";

// The Lambda runtime provides the AWS SDK, so it is not installed here. Each
// @aws-sdk/client-* import resolves to a stub whose send() calls __fakeAwsSend.
const SDK_EXPORTS = {
  "@aws-sdk/client-rds": ["RDSClient", "DescribePendingMaintenanceActionsCommand", "DescribeDBClustersCommand"],
  "@aws-sdk/client-elasticache": [
    "ElastiCacheClient",
    "DescribeUpdateActionsCommand",
    "DescribeCacheClustersCommand",
    "DescribeReplicationGroupsCommand",
  ],
  "@aws-sdk/client-ec2": [
    "EC2Client",
    "DescribeVolumesCommand",
    "DescribeSnapshotsCommand",
    "DescribeImagesCommand",
    "DescribeInstancesCommand",
  ],
  "@aws-sdk/client-eks": ["EKSClient", "ListClustersCommand", "DescribeClusterCommand"],
  "@aws-sdk/client-acm": ["ACMClient", "ListCertificatesCommand", "DescribeCertificateCommand"],
  "@aws-sdk/client-iam": ["IAMClient", "ListUsersCommand", "ListAccessKeysCommand"],
  "@aws-sdk/client-savingsplans": ["SavingsplansClient", "DescribeSavingsPlansCommand"],
};

function stubSource(pkg) {
  return SDK_EXPORTS[pkg]
    .map((name) => name.endsWith("Client")
      ? `export class ${name} { constructor(config) { this.region = config?.region; } ` +
        `send(command) { return globalThis.__fakeAwsSend(this.region, command.constructor.name, command.input); } }`
      : `export class ${name} { constructor(input) { this.input = input; } }`)
    .join("\n");
}

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (Object.hasOwn(SDK_EXPORTS, specifier)) {
      return { url: `data:text/javascript,${encodeURIComponent(stubSource(specifier))}`, shortCircuit: true };
    }
    return nextResolve(specifier, context);
  },
});

// config.mjs reads the environment once at import time, so it has to be set
// before the check and the handler are loaded.
process.env.SLACK_WEBHOOK_URL = "https://hooks.slack.example/services/T000/B000/XXXX";
process.env.AWS_ACCOUNT_NAME = "example-account";
process.env.AWS_REGIONS = "eu-west-1";
process.env.RDS_MAINTENANCE_IGNORED_ACTIONS = "os-upgrade";
delete process.env.SLACK_BOT_TOKEN;
delete process.env.SLACK_CHANNEL;

const rdsMaintenance = await import("../../src/aws-events-to-slack/lib/checks/rds-maintenance.mjs");
const { handleScheduledCheck } = await import("../../src/aws-events-to-slack/lib/handlers/scheduled.mjs");

const REGION = "eu-west-1";

function resource(name, ...details) {
  return {
    ResourceIdentifier: `arn:aws:rds:${REGION}:123456789012:db:${name}`,
    PendingMaintenanceActionDetails: details,
  };
}

const OS_UPGRADE = {
  Action: "os-upgrade",
  AutoAppliedAfterDate: new Date("2029-12-01T00:00:00Z"),
  Description: "New Operating System patch is available",
};
const SYSTEM_UPDATE = {
  Action: "system-update",
  AutoAppliedAfterDate: new Date("2030-01-01T00:00:00Z"),
  Description: "Aurora maintenance patch",
};
const DB_UPGRADE = {
  Action: "db-upgrade",
  ForcedApplyDate: new Date("2030-02-01T00:00:00Z"),
  Description: "Engine minor version upgrade",
};

const OS_UPGRADE_ONLY = [resource("app-db-0", OS_UPGRADE), resource("app-db-1", OS_UPGRADE)];
const MIXED = [
  resource("app-db-0", OS_UPGRADE),
  resource("app-db-1", OS_UPGRADE, SYSTEM_UPDATE),
  resource("app-db-2", DB_UPGRADE),
];

const UNDATED_OS_PATCH = { Action: "system-update", Description: "New Operating System patch is available" };
const UNDATED_CLUSTER_OS_PATCH = { Action: "os-upgrade", Description: "New Operating System patch is available" };
const DATED_ENGINE_UPGRADE = {
  Action: "system-update",
  AutoAppliedAfterDate: new Date("2030-03-01T00:00:00Z"),
  Description: "Upgrade to Aurora PostgreSQL 16.13.5",
};
const FORCED_ONLY = {
  Action: "db-upgrade",
  ForcedApplyDate: new Date("2030-04-01T00:00:00Z"),
  Description: "Engine minor version upgrade",
};
const OPTED_IN = {
  Action: "system-update",
  OptInStatus: "next-maintenance",
  CurrentApplyDate: new Date("2030-05-01T00:00:00Z"),
  Description: "New Operating System patch is available",
};

function cluster(name, ...details) {
  return {
    ResourceIdentifier: `arn:aws:rds:${REGION}:123456789012:cluster:${name}`,
    PendingMaintenanceActionDetails: details,
  };
}

const UNDATED_ONLY = [
  cluster("app-cluster", UNDATED_CLUSTER_OS_PATCH),
  resource("app-db-0", UNDATED_OS_PATCH),
  resource("app-db-1", UNDATED_OS_PATCH),
];

let pending;
let posted;

globalThis.__fakeAwsSend = async (_region, commandName) => {
  if (commandName === "DescribePendingMaintenanceActionsCommand") {
    return { PendingMaintenanceActions: pending };
  }
  return {};
};

before(() => {
  mock.method(https, "request", (_options, callback) => {
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
  mock.method(console, "log", () => {});
  mock.method(console, "error", () => {});
});

after(() => mock.restoreAll());

beforeEach(() => {
  posted = [];
});

function reportText(message) {
  return message.blocks[0].text.text;
}

describe("RDS maintenance check with ignored action types", () => {
  it("reports every action when no action type is ignored", async () => {
    pending = MIXED;
    const findings = await rdsMaintenance.check([REGION], []);

    assert.deepEqual(findings.map((f) => f.PendingMaintenanceActionDetails.map((d) => d.Action)), [
      ["os-upgrade"],
      ["os-upgrade", "system-update"],
      ["db-upgrade"],
    ]);
    const text = reportText(rdsMaintenance.format(findings));
    assert.ok(text.includes("4 pending action(s) across 3 resource(s)"));
    assert.ok(text.includes("- os-upgrade | Auto-apply: 2029-12-01"));
  });

  it("finds nothing when every pending action is of an ignored type", async () => {
    pending = OS_UPGRADE_ONLY;
    assert.deepEqual(await rdsMaintenance.check([REGION], ["os-upgrade"]), []);
  });

  it("keeps only the actions of other types in a mixed batch", async () => {
    pending = MIXED;
    const findings = await rdsMaintenance.check([REGION], ["os-upgrade"]);

    assert.deepEqual(findings.map((f) => f.ResourceIdentifier.split(":").pop()), ["app-db-1", "app-db-2"]);
    const text = reportText(rdsMaintenance.format(findings));
    assert.ok(text.includes("2 pending action(s) across 2 resource(s)"));
    assert.ok(text.includes("- system-update | Auto-apply: 2030-01-01"));
    assert.ok(text.includes("- db-upgrade | Auto-apply: 2030-02-01"));
    assert.ok(!text.includes("os-upgrade"));
    assert.ok(!text.includes("app-db-0"));
  });

  it("still reports a region whose check failed when every action is ignored", async () => {
    pending = OS_UPGRADE_ONLY;
    const original = globalThis.__fakeAwsSend;
    globalThis.__fakeAwsSend = async () => {
      throw new Error("simulated regional outage");
    };
    try {
      const findings = await rdsMaintenance.check([REGION], ["os-upgrade"]);
      assert.deepEqual(findings, [{ checkError: true, region: REGION, message: "simulated regional outage" }]);
    } finally {
      globalThis.__fakeAwsSend = original;
    }
  });
});

describe("scheduled check with RDS_MAINTENANCE_IGNORED_ACTIONS=os-upgrade", () => {
  it("sends no report for a batch of only os-upgrade actions", async () => {
    pending = OS_UPGRADE_ONLY;
    const result = await handleScheduledCheck();

    assert.deepEqual(result, { statusCode: 200, body: "OK" });
    assert.deepEqual(posted, []);
  });

  it("sends one report listing only the other actions of a mixed batch", async () => {
    pending = MIXED;
    await handleScheduledCheck();

    assert.equal(posted.length, 1);
    assert.equal(posted[0].text, ":calendar: RDS Pending Maintenance - 2 action(s)");
    const text = reportText(posted[0]);
    assert.ok(text.includes("system-update"));
    assert.ok(text.includes("db-upgrade"));
    assert.ok(!text.includes("os-upgrade"));
  });
});

describe("RDS maintenance check with undated actions", () => {
  it("finds nothing when no pending action has an apply date", async () => {
    pending = UNDATED_ONLY;
    assert.deepEqual(await rdsMaintenance.check([REGION], []), []);
  });

  it("keeps a dated engine upgrade of the same action type as an undated OS patch", async () => {
    pending = [resource("app-db-0", UNDATED_OS_PATCH), resource("app-db-1", UNDATED_OS_PATCH, DATED_ENGINE_UPGRADE)];
    const findings = await rdsMaintenance.check([REGION], []);

    assert.deepEqual(findings.map((f) => f.ResourceIdentifier.split(":").pop()), ["app-db-1"]);
    const text = reportText(rdsMaintenance.format(findings));
    assert.ok(text.includes("1 pending action(s) across 1 resource(s)"));
    assert.ok(text.includes("- system-update | Auto-apply: 2030-03-01"));
    assert.ok(text.includes("Upgrade to Aurora PostgreSQL 16.13.5"));
    assert.ok(!text.includes("New Operating System patch is available"));
  });

  it("keeps an action dated only by its forced apply date or by a next-maintenance opt-in", async () => {
    pending = [resource("app-db-0", FORCED_ONLY), resource("app-db-1", OPTED_IN)];
    const findings = await rdsMaintenance.check([REGION], []);

    const text = reportText(rdsMaintenance.format(findings));
    assert.ok(text.includes("2 pending action(s) across 2 resource(s)"));
    assert.ok(text.includes("- db-upgrade | Auto-apply: 2030-04-01"));
    assert.ok(text.includes("- system-update | Auto-apply: 2030-05-01"));
    assert.deepEqual(rdsMaintenance.summarize(findings), [
      `app-db-0 (${REGION}): db-upgrade auto-apply 2030-04-01`,
      `app-db-1 (${REGION}): system-update auto-apply 2030-05-01`,
    ]);
  });
});

describe("scheduled check with undated actions", () => {
  it("sends no report for a batch of only undated actions", async () => {
    pending = UNDATED_ONLY;
    const result = await handleScheduledCheck();

    assert.deepEqual(result, { statusCode: 200, body: "OK" });
    assert.deepEqual(posted, []);
  });

  it("sends one report listing only the dated actions", async () => {
    pending = [...UNDATED_ONLY, resource("app-db-2", DATED_ENGINE_UPGRADE)];
    await handleScheduledCheck();

    assert.equal(posted.length, 1);
    assert.equal(posted[0].text, ":calendar: RDS Pending Maintenance - 1 action(s)");
    const text = reportText(posted[0]);
    assert.ok(text.includes("app-db-2"));
    assert.ok(!text.includes("app-cluster"));
    assert.ok(!text.includes("app-db-0"));
  });
});
