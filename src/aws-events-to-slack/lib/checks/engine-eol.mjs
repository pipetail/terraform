import { RDSClient, DescribeDBClustersCommand } from "@aws-sdk/client-rds";
import { ElastiCacheClient, DescribeCacheClustersCommand } from "@aws-sdk/client-elasticache";
import { ENGINE_EOL_DATES, EOL_WARNING_MONTHS, EOL_URGENT_MONTHS, AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check(regions) {
  const now = new Date();
  const warnings = [];

  for (const region of regions) {
    const rdsWarnings = await getRdsEolWarnings(region, now);
    warnings.push(...rdsWarnings);

    const elasticacheWarnings = await getElasticacheEolWarnings(region, now);
    warnings.push(...elasticacheWarnings);
  }

  return warnings;
}

async function getRdsEolWarnings(region, now) {
  const warnings = [];
  const client = new RDSClient({ region });
  let marker;

  do {
    const response = await client.send(new DescribeDBClustersCommand({ Marker: marker }));
    for (const cluster of response.DBClusters || []) {
      const engine = cluster.Engine;
      const engineMap = ENGINE_EOL_DATES[engine];
      if (!engineMap) continue;

      const majorVersion = cluster.EngineVersion?.split(".")[0];
      const eolEntry = engineMap[majorVersion];
      if (!eolEntry) continue;

      const result = checkEolDate(eolEntry, now);
      if (!result) continue;

      warnings.push({
        name: cluster.DBClusterIdentifier,
        engine,
        version: cluster.EngineVersion,
        region,
        ...result,
        successor: eolEntry.successor,
        eolDate: eolEntry.eol,
      });
    }
    marker = response.Marker;
  } while (marker);

  return warnings;
}

async function getElasticacheEolWarnings(region, now) {
  const warnings = [];
  const client = new ElastiCacheClient({ region });
  const seen = new Set();
  let marker;

  do {
    const response = await client.send(new DescribeCacheClustersCommand({ Marker: marker }));
    for (const cluster of response.CacheClusters || []) {
      const groupId = cluster.ReplicationGroupId || cluster.CacheClusterId;
      if (seen.has(groupId)) continue;
      seen.add(groupId);

      const engineMap = ENGINE_EOL_DATES[cluster.Engine];
      if (!engineMap) continue;

      const version = cluster.EngineVersion;
      const majorMinor = version?.split(".").slice(0, 2).join(".");
      const eolEntry = engineMap[majorMinor];
      if (!eolEntry) continue;

      const result = checkEolDate(eolEntry, now);
      if (!result) continue;

      warnings.push({
        name: groupId,
        engine: cluster.Engine,
        version,
        region,
        ...result,
        successor: eolEntry.successor,
        eolDate: eolEntry.eol,
      });
    }
    marker = response.Marker;
  } while (marker);

  return warnings;
}

function checkEolDate(eolEntry, now) {
  const eolDate = new Date(eolEntry.eol + "T00:00:00Z");
  const diffMs = eolDate - now;
  const monthsRemaining = diffMs / (1000 * 60 * 60 * 24 * 30.44);

  if (monthsRemaining < 0) {
    return { severity: "expired", monthsRemaining: Math.round(monthsRemaining) };
  }
  if (monthsRemaining <= EOL_URGENT_MONTHS) {
    return { severity: "urgent", monthsRemaining: Math.round(monthsRemaining) };
  }
  if (monthsRemaining <= EOL_WARNING_MONTHS) {
    return { severity: "warning", monthsRemaining: Math.round(monthsRemaining) };
  }
  return null;
}

export function summarize(warnings) {
  return warnings.map((w) => {
    const status = w.severity === "expired" ? "EXPIRED" : `${w.monthsRemaining} month(s) remaining`;
    return `${w.name} ${w.engine} ${w.version} (${w.region}): EOL ${w.eolDate}, ${status}, upgrade to ${w.successor}`;
  });
}

export function format(warnings) {
  const urgent = warnings.filter((w) => w.severity === "expired" || w.severity === "urgent");
  const info = warnings.filter((w) => w.severity === "warning");

  let text = `:warning: Engine End-of-Life Report\n\n${warnings.length} engine(s) approaching or past EOL:\n`;

  if (urgent.length > 0) {
    text += `\n:rotating_light: *Urgent* (≤${EOL_URGENT_MONTHS} months or expired):\n`;
    for (const w of urgent) {
      const status = w.severity === "expired" ? "*EXPIRED*" : `${w.monthsRemaining} month(s) remaining`;
      text += `\n* \`${w.name}\` — ${w.engine} ${w.version} (${w.region})`;
      text += `\n  EOL: ${w.eolDate} — ${status}`;
      text += `\n  Upgrade to: ${w.successor}`;
    }
  }

  if (info.length > 0) {
    text += `\n\n:large_yellow_circle: *Upcoming* (≤${EOL_WARNING_MONTHS} months):\n`;
    for (const w of info) {
      text += `\n* \`${w.name}\` — ${w.engine} ${w.version} (${w.region})`;
      text += `\n  EOL: ${w.eolDate} — ${w.monthsRemaining} month(s) remaining`;
      text += `\n  Upgrade to: ${w.successor}`;
    }
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:warning: Engine EOL Report - ${warnings.length} warning(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
