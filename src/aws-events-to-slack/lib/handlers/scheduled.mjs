import { AWS_REGIONS } from "../config.mjs";
import { postToSlack, logSlackForward, severityFromColor } from "../slack.mjs";
import * as rdsMaintenance from "../checks/rds-maintenance.mjs";
import * as elasticacheUpdates from "../checks/elasticache-updates.mjs";
import * as engineEol from "../checks/engine-eol.mjs";
import * as acmCertificates from "../checks/acm-certificates.mjs";
import * as eksEol from "../checks/eks-eol.mjs";
import * as savingsPlans from "../checks/savings-plans.mjs";
import * as iamAccessKeys from "../checks/iam-access-keys.mjs";
import * as ebsResources from "../checks/ebs-resources.mjs";
import * as amiCleanup from "../checks/ami-cleanup.mjs";

const checks = [
  { name: "RDS maintenance", module: rdsMaintenance, regional: true },
  { name: "ElastiCache updates", module: elasticacheUpdates, regional: true },
  { name: "Engine EOL", module: engineEol, regional: true },
  { name: "ACM certificates", module: acmCertificates, regional: true },
  { name: "EKS EOL", module: eksEol, regional: true },
  { name: "Savings Plans", module: savingsPlans, regional: false },
  { name: "IAM access keys", module: iamAccessKeys, regional: false, frequency: "weekly" },
  { name: "EBS resources", module: ebsResources, regional: true },
  { name: "AMI cleanup", module: amiCleanup, regional: true },
];

const MAX_BODY_FINDINGS = 10;

function findingsBody(module, findings) {
  if (typeof module.summarize !== "function") return undefined;
  const lines = module.summarize(findings);
  let body = lines.slice(0, MAX_BODY_FINDINGS).join("; ");
  if (lines.length > MAX_BODY_FINDINGS) {
    body += `; ...and ${lines.length - MAX_BODY_FINDINGS} more`;
  }
  return body;
}

export async function handleScheduledCheck() {
  const dayOfWeek = new Date().getUTCDay();
  const isMonday = dayOfWeek === 1;
  const activeChecks = checks.filter((c) => c.frequency !== "weekly" || isMonday);

  const results = await Promise.allSettled(
    activeChecks.map((c) => c.regional ? c.module.check(AWS_REGIONS) : c.module.check()),
  );

  for (let i = 0; i < results.length; i++) {
    if (results[i].status === "rejected") {
      console.error(`Failed to fetch ${activeChecks[i].name}:`, results[i].reason);
      continue;
    }

    const findings = results[i].value;
    if (findings.length > 0) {
      const message = activeChecks[i].module.format(findings);
      await postToSlack(message);
      logSlackForward({
        category: "maintenance",
        severity: severityFromColor(message.attachments?.[0]?.color),
        title: `${activeChecks[i].name}: ${findings.length} finding(s)`,
        body: findingsBody(activeChecks[i].module, findings),
      });
    } else {
      console.log(`No ${activeChecks[i].name} findings`);
    }
  }

  return { statusCode: 200, body: "OK" };
}
