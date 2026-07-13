import { ACMClient, ListCertificatesCommand } from "@aws-sdk/client-acm";
import { CERT_EXPIRY_WARNING_DAYS, AWS_ACCOUNT_NAME } from "../config.mjs";

export async function check(regions) {
  const now = new Date();
  const warningDate = new Date(now.getTime() + CERT_EXPIRY_WARNING_DAYS * 24 * 60 * 60 * 1000);
  const warnings = [];

  for (const region of regions) {
    const client = new ACMClient({ region });
    let nextToken;

    do {
      const response = await client.send(new ListCertificatesCommand({
        CertificateStatuses: ["ISSUED"],
        NextToken: nextToken,
      }));

      for (const cert of response.CertificateSummaryList || []) {
        if (!cert.NotAfter) continue;
        const expiry = new Date(cert.NotAfter);
        if (expiry <= warningDate) {
          const daysRemaining = Math.round((expiry - now) / (1000 * 60 * 60 * 24));
          warnings.push({
            domain: cert.DomainName,
            arn: cert.CertificateArn,
            expiry: expiry.toISOString().split("T")[0],
            daysRemaining,
            region,
            renewalEligibility: cert.RenewalEligibility || "UNKNOWN",
          });
        }
      }
      nextToken = response.NextToken;
    } while (nextToken);
  }

  return warnings;
}

export function summarize(warnings) {
  return warnings.map((w) => {
    const status = w.daysRemaining <= 0
      ? `expired ${w.expiry}`
      : `expires ${w.expiry} (${w.daysRemaining} days)`;
    return `${w.domain} (${w.region}): ${status}, renewal ${w.renewalEligibility}`;
  });
}

export function format(warnings) {
  const expired = warnings.filter((w) => w.daysRemaining <= 0);
  const expiring = warnings.filter((w) => w.daysRemaining > 0);

  let text = `:lock: ACM Certificate Expiry Report\n\n${warnings.length} certificate(s) expiring soon:\n`;

  if (expired.length > 0) {
    text += `\n:rotating_light: *Expired:*\n`;
    for (const w of expired) {
      text += `\n* \`${w.domain}\` (${w.region})`;
      text += `\n  Expired: ${w.expiry} | Renewal: ${w.renewalEligibility}`;
    }
  }

  if (expiring.length > 0) {
    text += `\n\n:warning: *Expiring within ${CERT_EXPIRY_WARNING_DAYS} days:*\n`;
    for (const w of expiring) {
      text += `\n* \`${w.domain}\` (${w.region})`;
      text += `\n  Expires: ${w.expiry} (${w.daysRemaining} days) | Renewal: ${w.renewalEligibility}`;
    }
  }

  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  return {
    text: `:lock: ACM Certificate Expiry - ${warnings.length} warning(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
