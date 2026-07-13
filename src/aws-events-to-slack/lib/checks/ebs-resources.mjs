import { EC2Client, DescribeVolumesCommand, DescribeSnapshotsCommand, DescribeImagesCommand } from "@aws-sdk/client-ec2";
import { EBS_SNAPSHOT_AGE_DAYS, AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check(regions) {
  const now = new Date();
  const warnings = [];

  for (const region of regions) {
    const client = new EC2Client({ region });

    let volNextToken;
    do {
      const volResponse = await client.send(new DescribeVolumesCommand({
        Filters: [{ Name: "status", Values: ["available"] }],
        NextToken: volNextToken,
      }));
      for (const vol of volResponse.Volumes || []) {
        warnings.push({
          type: "volume",
          id: vol.VolumeId,
          size: vol.Size,
          created: vol.CreateTime ? new Date(vol.CreateTime).toISOString().split("T")[0] : "unknown",
          region,
        });
      }
      volNextToken = volResponse.NextToken;
    } while (volNextToken);

    const amiResponse = await client.send(new DescribeImagesCommand({ Owners: ["self"] }));
    const amiSnapshotIds = new Set();
    for (const image of amiResponse.Images || []) {
      for (const bdm of image.BlockDeviceMappings || []) {
        if (bdm.Ebs?.SnapshotId) amiSnapshotIds.add(bdm.Ebs.SnapshotId);
      }
    }

    const snapshotCutoff = new Date(now.getTime() - EBS_SNAPSHOT_AGE_DAYS * 24 * 60 * 60 * 1000);
    let snapNextToken;
    do {
      const snapResponse = await client.send(new DescribeSnapshotsCommand({
        OwnerIds: ["self"],
        Filters: [{ Name: "status", Values: ["completed"] }],
        NextToken: snapNextToken,
      }));
      for (const snap of snapResponse.Snapshots || []) {
        if (!snap.StartTime) continue;
        if (amiSnapshotIds.has(snap.SnapshotId)) continue;
        const startTime = new Date(snap.StartTime);
        if (startTime <= snapshotCutoff) {
          warnings.push({
            type: "snapshot",
            id: snap.SnapshotId,
            size: snap.VolumeSize,
            created: startTime.toISOString().split("T")[0],
            region,
            description: snap.Description || "",
          });
        }
      }
      snapNextToken = snapResponse.NextToken;
    } while (snapNextToken);
  }

  return warnings;
}

export function summarize(warnings) {
  return warnings.map((w) =>
    `${w.type} ${w.id} ${w.size} GiB (${w.region}) created ${w.created}`,
  );
}

export function format(warnings) {
  const volumes = warnings.filter((w) => w.type === "volume");
  const snapshots = warnings.filter((w) => w.type === "snapshot");

  let text = `:floppy_disk: EBS Resources Report\n\n`;

  if (volumes.length > 0) {
    const totalSize = volumes.reduce((sum, v) => sum + (v.size || 0), 0);
    text += `*Unused Volumes:* ${volumes.length} (${totalSize} GiB total)\n`;
    for (const v of volumes.slice(0, 20)) {
      text += `\n* \`${v.id}\` — ${v.size} GiB (${v.region}) created ${v.created}`;
    }
    if (volumes.length > 20) {
      text += `\n  ...and ${volumes.length - 20} more`;
    }
  }

  if (snapshots.length > 0) {
    const totalSize = snapshots.reduce((sum, s) => sum + (s.size || 0), 0);
    text += `\n\n*Old Snapshots (>${EBS_SNAPSHOT_AGE_DAYS} days):* ${snapshots.length} (${totalSize} GiB total)\n`;
    for (const s of snapshots.slice(0, 20)) {
      text += `\n* \`${s.id}\` — ${s.size} GiB (${s.region}) created ${s.created}`;
    }
    if (snapshots.length > 20) {
      text += `\n  ...and ${snapshots.length - 20} more`;
    }
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:floppy_disk: EBS Resources - ${warnings.length} finding(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
