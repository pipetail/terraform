import { after, before, describe, it, mock } from "node:test";
import assert from "node:assert/strict";
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
};

function stubSource(pkg) {
  return SDK_EXPORTS[pkg]
    .map((name) => name.endsWith("Client")
      ? `export class ${name} { constructor(config) { this.region = config.region; } ` +
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

process.env.AWS_ACCOUNT_NAME = "example-account";

const FAILING_REGION = "me-central-1";
const HEALTHY_REGION = "eu-west-1";
const REGIONS = [FAILING_REGION, HEALTHY_REGION];
const FAILURE_MESSAGE = "simulated regional outage";

const RESPONSES = {
  DescribePendingMaintenanceActionsCommand: {
    PendingMaintenanceActions: [{
      ResourceIdentifier: "arn:aws:rds:eu-west-1:123456789012:db:app-db",
      PendingMaintenanceActionDetails: [{
        Action: "system-update",
        AutoAppliedAfterDate: new Date("2030-01-01T00:00:00Z"),
        Description: "patch",
      }],
    }],
  },
  DescribeDBClustersCommand: {
    DBClusters: [{ DBClusterIdentifier: "app-aurora", Engine: "aurora-postgresql", EngineVersion: "13.9" }],
  },
  DescribeCacheClustersCommand: {
    CacheClusters: [{ CacheClusterId: "app-cache-001", ReplicationGroupId: "app-cache", Engine: "redis", EngineVersion: "4.0.10" }],
  },
  DescribeReplicationGroupsCommand: {
    ReplicationGroups: [{ ReplicationGroupId: "app-cache", MemberClusters: ["app-cache-001"] }],
  },
  DescribeUpdateActionsCommand: {
    UpdateActions: [{
      ReplicationGroupId: "app-cache",
      Engine: "redis",
      UpdateActionStatus: "not-applied",
      ServiceUpdateName: "elasticache-patch-update",
      ServiceUpdateSeverity: "important",
    }],
  },
  DescribeVolumesCommand: {
    Volumes: [{ VolumeId: "vol-0123456789abcdef0", Size: 8, CreateTime: new Date("2024-01-01T00:00:00Z") }],
  },
  DescribeSnapshotsCommand: { Snapshots: [] },
  DescribeImagesCommand: {
    Images: [
      { ImageId: "ami-0000000000000new", Name: "app-2", CreationDate: "2020-02-01T00:00:00Z" },
      { ImageId: "ami-0000000000000old", Name: "app-1", CreationDate: "2020-01-01T00:00:00Z" },
    ],
  },
  DescribeInstancesCommand: { Reservations: [] },
  ListClustersCommand: { clusters: ["app-eks"] },
  DescribeClusterCommand: { cluster: { name: "app-eks", version: "1.27" } },
};

globalThis.__fakeAwsSend = async (region, commandName) => {
  if (region === FAILING_REGION) throw new Error(FAILURE_MESSAGE);
  if (!Object.hasOwn(RESPONSES, commandName)) throw new Error(`no fake response for ${commandName}`);
  return RESPONSES[commandName];
};

before(() => {
  mock.method(console, "error", () => {});
});

after(() => mock.restoreAll());

const CASES = [
  { file: "rds-maintenance", marker: "app-db" },
  { file: "elasticache-updates", marker: "app-cache" },
  { file: "engine-eol", marker: "app-aurora" },
  { file: "eks-eol", marker: "app-eks" },
  { file: "ebs-resources", marker: "vol-0123456789abcdef0" },
  { file: "ami-cleanup", marker: "ami-0000000000000old" },
];

describe("regional checks isolate a failing region", () => {
  for (const { file, marker } of CASES) {
    it(`${file} keeps the healthy region's findings and records the failure`, async () => {
      const check = await import(`../../src/aws-events-to-slack/lib/checks/${file}.mjs`);
      const result = await check.check(REGIONS);

      const errors = result.filter((f) => f.checkError);
      const findings = result.filter((f) => !f.checkError);

      assert.deepEqual(errors, [{ checkError: true, region: FAILING_REGION, message: FAILURE_MESSAGE }]);
      assert.ok(findings.length > 0, "healthy region findings are kept");
      for (const finding of findings) {
        assert.equal(finding.region ?? finding.Region, HEALTHY_REGION);
      }

      const summary = check.summarize(result);
      assert.equal(summary.length, findings.length);
      assert.ok(summary.every((line) => !line.includes(FAILING_REGION)));

      const text = check.format(result).blocks[0].text.text;
      assert.ok(text.includes(marker), `report lists ${marker}`);
      assert.ok(
        text.includes(`:x: *Check errors:*\n\n* region \`${FAILING_REGION}\`: check failed: ${FAILURE_MESSAGE}`),
        "report lists the failing region",
      );
    });
  }
});
