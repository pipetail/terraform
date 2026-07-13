import { ElastiCacheClient, DescribeUpdateActionsCommand, DescribeCacheClustersCommand, DescribeReplicationGroupsCommand } from "@aws-sdk/client-elasticache";
import { AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check(regions) {
  const allActions = [];
  const pendingStatuses = new Set(["not-applied", "waiting-to-start", "scheduled"]);

  for (const region of regions) {
    const client = new ElastiCacheClient({ region });

    // Build a map of existing clusters/replication groups and their engines,
    // so we can skip updates for deleted clusters and engine-migrated clusters
    // (e.g. redis -> valkey upgrades leave stale redis update actions behind)
    const clusterEngines = new Map();

    const clustersResponse = await client.send(new DescribeCacheClustersCommand({}));
    for (const c of clustersResponse.CacheClusters || []) {
      clusterEngines.set(c.CacheClusterId, c.Engine);
    }

    const rgResponse = await client.send(new DescribeReplicationGroupsCommand({}));
    for (const rg of rgResponse.ReplicationGroups || []) {
      const firstMember = (rg.MemberClusters || [])[0];
      if (firstMember && clusterEngines.has(firstMember)) {
        clusterEngines.set(rg.ReplicationGroupId, clusterEngines.get(firstMember));
      }
    }

    const response = await client.send(new DescribeUpdateActionsCommand({}));

    if (response.UpdateActions) {
      for (const action of response.UpdateActions) {
        if (!pendingStatuses.has(action.UpdateActionStatus)) continue;
        const clusterId = action.ReplicationGroupId || action.CacheClusterId;
        if (clusterId && !clusterEngines.has(clusterId)) continue;
        if (clusterId && action.Engine && clusterEngines.get(clusterId) !== action.Engine) continue;
        allActions.push({ ...action, Region: region });
      }
    }
  }

  return allActions;
}

export function summarize(actions) {
  return actions.map((action) => {
    const groupId = action.ReplicationGroupId || action.CacheClusterId || "unknown";
    const severity = action.ServiceUpdateSeverity || "unknown";
    const updateName = action.ServiceUpdateName || "unknown";
    const applyBy = action.ServiceUpdateRecommendedApplyByDate
      ? new Date(action.ServiceUpdateRecommendedApplyByDate).toISOString().split("T")[0]
      : "N/A";
    return `${groupId} (${action.Region}): ${updateName} severity ${severity}, apply by ${applyBy}`;
  });
}

export function format(actions) {
  let text = `:calendar: ElastiCache Pending Updates\n\n${actions.length} pending update(s):\n`;

  for (const action of actions) {
    const groupId = action.ReplicationGroupId || action.CacheClusterId || "unknown";
    const region = action.Region;
    const severity = action.ServiceUpdateSeverity || "unknown";
    const updateName = action.ServiceUpdateName || "unknown";
    const applyBy = action.ServiceUpdateRecommendedApplyByDate
      ? new Date(action.ServiceUpdateRecommendedApplyByDate).toISOString().split("T")[0]
      : "N/A";

    text += `\n* \`${groupId}\` (${region})`;
    text += `\n  - ${updateName} | Severity: ${severity} | Apply by: ${applyBy}`;
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:calendar: ElastiCache Pending Updates - ${actions.length} action(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
