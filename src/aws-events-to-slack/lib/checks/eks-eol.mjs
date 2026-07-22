import { EKSClient, ListClustersCommand, DescribeClusterCommand } from "@aws-sdk/client-eks";
import { EKS_EOL_DATES, EOL_WARNING_MONTHS, EOL_URGENT_MONTHS, AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check(regions) {
  const now = new Date();
  const warnings = [];

  for (const region of regions) {
    const client = new EKSClient({ region });
    let nextToken;

    do {
      const listResponse = await client.send(new ListClustersCommand({ nextToken }));
      for (const clusterName of listResponse.clusters || []) {
        const descResponse = await client.send(new DescribeClusterCommand({ name: clusterName }));
        const cluster = descResponse.cluster;
        if (!cluster) continue;

        const version = cluster.version;
        const eolEntry = EKS_EOL_DATES[version];
        if (!eolEntry) continue;

        const result = checkEolDate(eolEntry, now);
        if (!result) continue;

        warnings.push({
          name: clusterName,
          version,
          region,
          ...result,
          successor: eolEntry.successor,
          eolDate: eolEntry.eol,
        });
      }
      nextToken = listResponse.nextToken;
    } while (nextToken);
  }

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
    return `${w.name} EKS ${w.version} (${w.region}): EOL ${w.eolDate}, ${status}, upgrade to ${w.successor}`;
  });
}

export function format(warnings) {
  const urgent = warnings.filter((w) => w.severity === "expired" || w.severity === "urgent");
  const info = warnings.filter((w) => w.severity === "warning");

  let text = `:wheel_of_dharma: EKS Version EOL Report\n\n${warnings.length} cluster(s) approaching or past EOL:\n`;

  if (urgent.length > 0) {
    text += `\n:rotating_light: *Urgent* (≤${EOL_URGENT_MONTHS} months or expired):\n`;
    for (const w of urgent) {
      const status = w.severity === "expired" ? "*EXPIRED*" : `${w.monthsRemaining} month(s) remaining`;
      text += `\n* \`${w.name}\` — EKS ${w.version} (${w.region})`;
      text += `\n  EOL: ${w.eolDate} — ${status}`;
      text += `\n  Upgrade to: ${w.successor}`;
    }
  }

  if (info.length > 0) {
    text += `\n\n:large_yellow_circle: *Upcoming* (≤${EOL_WARNING_MONTHS} months):\n`;
    for (const w of info) {
      text += `\n* \`${w.name}\` — EKS ${w.version} (${w.region})`;
      text += `\n  EOL: ${w.eolDate} — ${w.monthsRemaining} month(s) remaining`;
      text += `\n  Upgrade to: ${w.successor}`;
    }
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:wheel_of_dharma: EKS EOL Report - ${warnings.length} warning(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
