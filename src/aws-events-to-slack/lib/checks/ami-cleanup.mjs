import { EC2Client, DescribeImagesCommand, DescribeInstancesCommand } from "@aws-sdk/client-ec2";
import { AWS_ACCOUNT_NAME, AMI_STALE_AGE_DAYS } from "../config.mjs";

// AMIs still booting an instance (any state, including stopped) are not safe to
// delete, regardless of age — skip them to avoid false positives.
async function getInUseImageIds(client) {
  const inUse = new Set();
  let nextToken;
  do {
    const response = await client.send(
      new DescribeInstancesCommand({ MaxResults: 1000, NextToken: nextToken }),
    );
    for (const reservation of response.Reservations || []) {
      for (const instance of reservation.Instances || []) {
        if (instance.ImageId) inUse.add(instance.ImageId);
      }
    }
    nextToken = response.NextToken;
  } while (nextToken);
  return inUse;
}

export async function check(regions) {
  const stale = [];
  const staleCutoff = new Date(Date.now() - AMI_STALE_AGE_DAYS * 24 * 60 * 60 * 1000);

  for (const region of regions) {
    const client = new EC2Client({ region });
    const response = await client.send(new DescribeImagesCommand({ Owners: ["self"] }));
    const images = response.Images || [];
    const inUse = await getInUseImageIds(client);

    const groups = new Map();
    for (const image of images) {
      if (!image.Name) continue;
      const prefix = image.Name.replace(/-\d+$/, "");
      if (!groups.has(prefix)) groups.set(prefix, []);
      groups.get(prefix).push(image);
    }

    for (const [prefix, groupImages] of groups) {
      if (groupImages.length <= 1) continue;
      groupImages.sort((a, b) => new Date(b.CreationDate) - new Date(a.CreationDate));
      for (const image of groupImages.slice(1)) {
        if (inUse.has(image.ImageId)) continue;
        const createdAt = new Date(image.CreationDate);
        if (createdAt > staleCutoff) continue;
        const ageDays = Math.floor((Date.now() - createdAt) / (1000 * 60 * 60 * 24));
        stale.push({
          id: image.ImageId,
          name: image.Name,
          created: new Date(image.CreationDate).toISOString().split("T")[0],
          ageDays,
          region,
        });
      }
    }
  }

  return stale;
}

export function summarize(findings) {
  return findings.map((ami) =>
    `${ami.id} ${ami.name} (${ami.region}) created ${ami.created} (${ami.ageDays}d old)`,
  );
}

export function format(findings) {
  let text = `:frame_with_picture: Stale AMIs Report\n\n`;
  text += `*Stale AMIs (not latest, >${AMI_STALE_AGE_DAYS}d old):* ${findings.length}\n`;

  for (const ami of findings.slice(0, 20)) {
    text += `\n* \`${ami.id}\` — ${ami.name} (${ami.region}) created ${ami.created} (${ami.ageDays}d ago)`;
  }
  if (findings.length > 20) {
    text += `\n  ...and ${findings.length - 20} more`;
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:frame_with_picture: Stale AMIs - ${findings.length} finding(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
