import { RDSClient, DescribePendingMaintenanceActionsCommand } from "@aws-sdk/client-rds";
import { AWS_ACCOUNT_NAME, RDS_MAINTENANCE_IGNORED_ACTIONS } from "../config.mjs";

// RDS never applies an action without one of these dates on its own, so an
// undated action is optional and not worth a daily report.
function applyDate(detail) {
  return detail.AutoAppliedAfterDate || detail.ForcedApplyDate || detail.CurrentApplyDate;
}

export async function check(regions, ignoredActions = RDS_MAINTENANCE_IGNORED_ACTIONS) {
  const allActions = [];

  for (const region of regions) {
    try {
      const client = new RDSClient({ region });
      let marker;

      do {
        const response = await client.send(new DescribePendingMaintenanceActionsCommand({ Marker: marker }));

        for (const action of response.PendingMaintenanceActions || []) {
          const details = action.PendingMaintenanceActionDetails || [];
          const kept = details.filter((detail) => applyDate(detail) && !ignoredActions.includes(detail.Action));
          // With no findings left, the scheduled handler sends no report.
          if (details.length > 0 && kept.length === 0) continue;
          allActions.push({ ...action, PendingMaintenanceActionDetails: kept, Region: region });
        }
        marker = response.Marker;
      } while (marker);
    } catch (error) {
      console.error(`Failed to fetch RDS maintenance in ${region}:`, error);
      allActions.push({ checkError: true, region, message: error.message });
    }
  }

  return allActions;
}

export function summarize(actions) {
  return actions.filter((a) => !a.checkError).map((action) => {
    const arn = action.ResourceIdentifier || "";
    const resourceName = arn.split(":").pop() || arn;
    const details = (action.PendingMaintenanceActionDetails || []).map((detail) => {
      const actionType = detail.Action || "unknown";
      const date = applyDate(detail);
      const autoApply = date ? new Date(date).toISOString().split("T")[0] : "N/A";
      return `${actionType} auto-apply ${autoApply}`;
    }).join(", ");
    return `${resourceName} (${action.Region}): ${details}`;
  });
}

export function format(actions) {
  const errors = actions.filter((a) => a.checkError);
  actions = actions.filter((a) => !a.checkError);

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
      const date = applyDate(detail);
      const autoApply = date ? new Date(date).toISOString().split("T")[0] : "N/A";
      const description = detail.Description || "";

      text += `\n  - ${actionType} | Auto-apply: ${autoApply}`;
      if (description) {
        text += `\n    "${description}"`;
      }
    }
  }

  if (errors.length > 0) {
    text += `\n\n:x: *Check errors:*\n`;
    for (const e of errors) {
      text += `\n* region \`${e.region}\`: check failed: ${e.message}`;
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
