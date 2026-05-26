import { RDSClient, DescribePendingMaintenanceActionsCommand } from "@aws-sdk/client-rds";
import { AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check(regions) {
  const allActions = [];

  for (const region of regions) {
    const client = new RDSClient({ region });
    let marker;

    do {
      const response = await client.send(new DescribePendingMaintenanceActionsCommand({ Marker: marker }));

      for (const action of response.PendingMaintenanceActions || []) {
        allActions.push({ ...action, Region: region });
      }
      marker = response.Marker;
    } while (marker);
  }

  return allActions;
}

export function format(actions) {
  const totalActions = actions.reduce(
    (sum, a) => sum + (a.PendingMaintenanceActionDetails?.length || 0),
    0,
  );
  const resourceCount = actions.length;

  let text = `:calendar: RDS Pending Maintenance\n\n${totalActions} pending action(s) across ${resourceCount} resource(s):\n`;

  for (const action of actions) {
    const arn = action.ResourceIdentifier || "";
    const resourceName = arn.split(":").pop() || arn;
    const region = action.Region;

    text += `\n* \`${resourceName}\` (${region})`;

    for (const detail of action.PendingMaintenanceActionDetails || []) {
      const actionType = detail.Action || "unknown";
      const autoApply = detail.AutoAppliedAfterDate
        ? new Date(detail.AutoAppliedAfterDate).toISOString().split("T")[0]
        : detail.ForcedApplyDate
          ? new Date(detail.ForcedApplyDate).toISOString().split("T")[0]
          : "N/A";
      const description = detail.Description || "";

      text += `\n  - ${actionType} | Auto-apply: ${autoApply}`;
      if (description) {
        text += `\n    "${description}"`;
      }
    }
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:calendar: RDS Pending Maintenance - ${totalActions} action(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
