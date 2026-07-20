import { ACMClient, ListCertificatesCommand, DescribeCertificateCommand } from "@aws-sdk/client-acm";
import { CERT_EXPIRY_WARNING_DAYS, CERT_EXPIRY_URGENT_DAYS, AWS_ACCOUNT_NAME } from "../config.mjs";

const DAY_MS = 24 * 60 * 60 * 1000;

// ACM reports SUCCESS once a renewal completes and PENDING_AUTO_RENEWAL while it
// still intends to renew on its own. Anything else inside the warning window
// means managed renewal is not going to finish without a human.
const AUTO_RENEWING_STATUSES = new Set(["SUCCESS", "PENDING_AUTO_RENEWAL"]);

function resourceName(arn) {
  const resource = arn.split(":").slice(5).join(":");
  const segments = resource.split("/");
  return segments.length >= 3 ? segments[segments.length - 2] : segments[segments.length - 1];
}

function classify(detail, renewalStatus) {
  // Imported certs have no managed renewal at all, and ACM flags certs it has
  // given up on as INELIGIBLE. Both need a replacement, not a DNS fix.
  if (detail.Type !== "AMAZON_ISSUED") return "manual";
  if (detail.RenewalEligibility === "INELIGIBLE") return "manual";
  if (AUTO_RENEWING_STATUSES.has(renewalStatus)) return "auto";
  return "stuck";
}

function isoDate(value) {
  return value ? new Date(value).toISOString().split("T")[0] : undefined;
}

export async function check(regions) {
  const now = new Date();
  const warningDate = new Date(now.getTime() + CERT_EXPIRY_WARNING_DAYS * DAY_MS);
  const findings = [];
  const errors = [];
  let suppressed = 0;

  for (const region of regions) {
    try {
      const client = new ACMClient({ region });
      const expiring = [];
      let nextToken;

      do {
        const response = await client.send(new ListCertificatesCommand({
          CertificateStatuses: ["ISSUED"],
          NextToken: nextToken,
        }));

        for (const cert of response.CertificateSummaryList || []) {
          if (!cert.NotAfter) continue;
          const expiry = new Date(cert.NotAfter);
          if (expiry <= warningDate) expiring.push({ cert, expiry });
        }
        nextToken = response.NextToken;
      } while (nextToken);

      // ListCertificates only carries RenewalEligibility, which says whether a
      // cert qualifies for managed renewal, never whether renewal is working.
      // The actual state lives in RenewalSummary, so describe the few certs
      // that already fall inside the warning window.
      const detailed = await Promise.all(expiring.map(async ({ cert, expiry }) => {
        const base = {
          domain: cert.DomainName,
          arn: cert.CertificateArn,
          expiry: expiry.toISOString().split("T")[0],
          daysRemaining: Math.round((expiry - now) / DAY_MS),
          region,
          renewalEligibility: cert.RenewalEligibility || "UNKNOWN",
        };

        try {
          const { Certificate: detail } = await client.send(
            new DescribeCertificateCommand({ CertificateArn: cert.CertificateArn }),
          );
          const renewal = detail.RenewalSummary;
          const renewalStatus = renewal?.RenewalStatus || "NOT_STARTED";
          const pending = (renewal?.DomainValidationOptions || [])
            .filter((option) => option.ValidationStatus !== "SUCCESS");

          return {
            ...base,
            category: classify(detail, renewalStatus),
            renewalStatus,
            renewalUpdatedAt: isoDate(renewal?.UpdatedAt),
            certificateType: detail.Type,
            inUseBy: (detail.InUseBy || []).map(resourceName),
            pendingValidation: pending.map((option) => ({
              domain: option.DomainName,
              recordName: option.ResourceRecord?.Name,
              recordType: option.ResourceRecord?.Type,
              recordValue: option.ResourceRecord?.Value,
            })),
          };
        } catch (error) {
          // Surface the cert anyway rather than dropping it: a missing
          // acm:DescribeCertificate grant must not silence the whole check.
          console.error(`Failed to describe certificate ${cert.CertificateArn}:`, error);
          return {
            ...base,
            category: "stuck",
            renewalStatus: "UNKNOWN",
            describeError: error.message,
            inUseBy: [],
            pendingValidation: [],
          };
        }
      }));

      for (const finding of detailed) {
        // Certs ACM is renewing on its own are noise until they get close
        // enough to expiry that a silent failure would actually hurt.
        if (finding.category === "auto" && finding.daysRemaining > CERT_EXPIRY_URGENT_DAYS) {
          suppressed++;
          continue;
        }
        findings.push(finding);
      }
    } catch (error) {
      console.error(`Failed to fetch ACM certificates in ${region}:`, error);
      errors.push({ checkError: true, region, message: error.message });
    }
  }

  if (findings.length === 0 && errors.length === 0) return [];

  const result = [...findings, ...errors];
  if (findings.length > 0 && suppressed > 0) {
    result.push({ suppressedNotice: true, count: suppressed });
  }
  return result;
}

export function summarize(findings) {
  return findings
    .filter((f) => !f.checkError && !f.suppressedNotice)
    .map((cert) => {
      const status = cert.daysRemaining <= 0
        ? `expired ${cert.expiry}`
        : `expires ${cert.expiry} (${cert.daysRemaining} days)`;
      return `${cert.domain} (${cert.region}): ${status}, renewal ${cert.renewalStatus}`;
    });
}

function renderCert(cert) {
  let text = `\n* \`${cert.domain}\` (${cert.region})`;

  const expiryLabel = cert.daysRemaining <= 0
    ? `Expired: ${cert.expiry}`
    : `Expires: ${cert.expiry} (${cert.daysRemaining} days)`;
  text += `\n  ${expiryLabel} | Renewal: ${cert.renewalStatus}`;
  if (cert.renewalUpdatedAt) text += ` (last attempt ${cert.renewalUpdatedAt})`;

  if (cert.describeError) {
    text += `\n  Could not read renewal status: ${cert.describeError}`;
  }

  if (cert.certificateType && cert.certificateType !== "AMAZON_ISSUED") {
    text += `\n  Type: ${cert.certificateType} (ACM does not renew this, replace it before expiry)`;
  } else if (cert.renewalEligibility === "INELIGIBLE") {
    text += `\n  Eligibility: INELIGIBLE (ACM will not renew this, replace it before expiry)`;
  }

  if (cert.inUseBy?.length) {
    text += `\n  In use by: ${cert.inUseBy.join(", ")}`;
  } else if (!cert.describeError) {
    text += `\n  Not in use by any resource (deleting it may be simpler than renewing)`;
  }

  if (cert.pendingValidation?.length) {
    text += `\n  Awaiting DNS validation:`;
    for (const pending of cert.pendingValidation) {
      text += `\n    ${pending.domain}`;
      if (pending.recordName) {
        text += `\n      \`${pending.recordName}\` ${pending.recordType} -> \`${pending.recordValue}\``;
      }
    }
  }

  return text;
}

export function format(findings) {
  const errors = findings.filter((f) => f.checkError);
  const notice = findings.find((f) => f.suppressedNotice);
  const certs = findings.filter((f) => !f.checkError && !f.suppressedNotice);

  const expired = certs.filter((c) => c.daysRemaining <= 0);
  const active = certs.filter((c) => c.daysRemaining > 0);
  const stuck = active.filter((c) => c.category === "stuck");
  const manual = active.filter((c) => c.category === "manual");
  const auto = active.filter((c) => c.category === "auto");

  const sections = [];
  const certSection = (heading, group) => {
    if (group.length > 0) sections.push(heading + group.map(renderCert).join("\n"));
  };

  certSection(`:rotating_light: *Expired:*\n`, expired);
  certSection(`:rotating_light: *Renewal stuck (needs action):*\n`, stuck);
  certSection(`:warning: *Manual renewal required:*\n`, manual);
  certSection(`:hourglass: *Renewing, but close to expiry:*\n`, auto);

  if (errors.length > 0) {
    sections.push(`:x: *Check errors:*\n` + errors
      .map((error) => `\n* region \`${error.region}\`: check failed: ${error.message}`)
      .join(""));
  }

  if (notice) {
    sections.push(`:information_source: ${notice.count} cert(s) renewing normally, not shown.`);
  }

  let text = `:lock: ACM Certificate Expiry Report\n`;
  if (certs.length > 0) {
    text += `\n${certs.length} certificate(s) need attention:\n`;
  }
  text += `\n${sections.join("\n\n")}`;
  text += `\n\nAccount: ${AWS_ACCOUNT_NAME || "Unknown"}`;

  const headline = certs.length > 0 ? certs.length : errors.length;
  return {
    text: `:lock: ACM Certificate Expiry - ${headline} warning(s)`,
    blocks: [
      {
        type: "section",
        text: { type: "mrkdwn", text },
      },
    ],
  };
}
