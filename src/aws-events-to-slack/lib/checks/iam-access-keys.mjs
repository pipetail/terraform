import { IAMClient, ListUsersCommand, ListAccessKeysCommand } from "@aws-sdk/client-iam";
import { ACCESS_KEY_WARNING_DAYS, AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check() {
  const now = new Date();
  const warnings = [];

  const client = new IAMClient({ region: "us-east-1" });
  let marker;

  do {
    const usersResponse = await client.send(new ListUsersCommand({ Marker: marker }));
    for (const user of usersResponse.Users || []) {
      const keysResponse = await client.send(new ListAccessKeysCommand({ UserName: user.UserName }));
      for (const key of keysResponse.AccessKeyMetadata || []) {
        if (key.Status !== "Active" || !key.CreateDate) continue;
        const ageDays = Math.round((now - new Date(key.CreateDate)) / (1000 * 60 * 60 * 24));
        if (ageDays >= ACCESS_KEY_WARNING_DAYS) {
          warnings.push({
            userName: user.UserName,
            accessKeyId: key.AccessKeyId,
            createDate: new Date(key.CreateDate).toISOString().split("T")[0],
            ageDays,
          });
        }
      }
    }
    marker = usersResponse.Marker;
  } while (marker);

  return warnings;
}

export function format(warnings) {
  let text = `:key: IAM Access Key Age Report\n\n${warnings.length} key(s) older than ${ACCESS_KEY_WARNING_DAYS} days:\n`;

  for (const w of warnings) {
    text += `\n* \`${w.userName}\` — key \`${w.accessKeyId.slice(0, 8)}...\``;
    text += `\n  Created: ${w.createDate} (${w.ageDays} days old)`;
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:key: IAM Access Key Age - ${warnings.length} warning(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
