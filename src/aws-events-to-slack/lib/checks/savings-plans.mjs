import { SavingsplansClient, DescribeSavingsPlansCommand } from "@aws-sdk/client-savingsplans";
import { SAVINGS_PLAN_WARNING_DAYS, AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check() {
  const now = new Date();
  const warningDate = new Date(now.getTime() + SAVINGS_PLAN_WARNING_DAYS * 24 * 60 * 60 * 1000);
  const warnings = [];

  const client = new SavingsplansClient({ region: "us-east-1" });
  const response = await client.send(new DescribeSavingsPlansCommand({
    states: ["active"],
  }));

  for (const plan of response.savingsPlans || []) {
    if (!plan.end) continue;
    const endDate = new Date(plan.end);
    if (endDate <= warningDate) {
      const daysRemaining = Math.round((endDate - now) / (1000 * 60 * 60 * 24));
      warnings.push({
        id: plan.savingsPlanId,
        type: plan.savingsPlanType,
        commitment: plan.commitment,
        currency: plan.currency,
        endDate: endDate.toISOString().split("T")[0],
        daysRemaining,
        paymentOption: plan.paymentOption,
      });
    }
  }

  return warnings;
}

export function format(warnings) {
  const expired = warnings.filter((w) => w.daysRemaining <= 0);
  const expiring = warnings.filter((w) => w.daysRemaining > 0);

  let text = `:moneybag: Savings Plans Expiry Report\n\n${warnings.length} plan(s) expiring soon:\n`;

  if (expired.length > 0) {
    text += `\n:rotating_light: *Expired:*\n`;
    for (const w of expired) {
      text += `\n* \`${w.id}\` — ${w.type}`;
      text += `\n  Expired: ${w.endDate} | Commitment: ${w.commitment} ${w.currency}/hr`;
    }
  }

  if (expiring.length > 0) {
    text += `\n\n:warning: *Expiring within ${SAVINGS_PLAN_WARNING_DAYS} days:*\n`;
    for (const w of expiring) {
      text += `\n* \`${w.id}\` — ${w.type}`;
      text += `\n  Expires: ${w.endDate} (${w.daysRemaining} days) | Commitment: ${w.commitment} ${w.currency}/hr`;
    }
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:moneybag: Savings Plans Expiry - ${warnings.length} warning(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
