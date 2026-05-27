export const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;
export const SLACK_BOT_TOKEN = process.env.SLACK_BOT_TOKEN;
export const SLACK_CHANNEL = process.env.SLACK_CHANNEL;
export const AWS_ACCOUNT_NAME = process.env.AWS_ACCOUNT_NAME;
// Optional link shown in budget alerts pointing to where thresholds are configured.
// When unset, the link is omitted.
export const THRESHOLDS_URL = process.env.THRESHOLDS_URL;
export const AWS_REGIONS = process.env.AWS_REGIONS
  ? process.env.AWS_REGIONS.split(",").map((r) => r.trim())
  : [process.env.AWS_REGION || "eu-west-1"];

export const ENGINE_EOL_DATES = {
  "aurora-postgresql": {
    "13": { eol: "2026-04-30", successor: "Aurora PostgreSQL 14 or 15" },
    "14": { eol: "2027-03-31", successor: "Aurora PostgreSQL 15 or 16" },
    "15": { eol: "2028-01-31", successor: "Aurora PostgreSQL 16 or 17" },
    "16": { eol: "2029-01-31", successor: "Aurora PostgreSQL 17" },
    "17": { eol: "2030-02-28", successor: "latest Aurora PostgreSQL version" },
  },
  redis: {
    "4.0": { eol: "2026-01-31", successor: "Valkey 7.2 or later" },
    "5.0": { eol: "2026-01-31", successor: "Valkey 7.2 or later" },
    "6.0": { eol: "2027-01-31", successor: "Valkey 7.2 or later" },
    "6.2": { eol: "2027-01-31", successor: "Valkey 7.2 or later" },
    "7.0": { eol: "2027-03-31", successor: "Valkey 8.0 or later" },
    "7.1": { eol: "2028-03-31", successor: "Valkey 8.0 or later" },
  },
  // No EOL dates published by AWS for Valkey yet
  valkey: {},
};

export const EKS_EOL_DATES = {
  "1.27": { eol: "2025-07-24", successor: "1.28 or later" },
  "1.28": { eol: "2025-11-26", successor: "1.29 or later" },
  "1.29": { eol: "2026-03-23", successor: "1.30 or later" },
  "1.30": { eol: "2026-07-23", successor: "1.31 or later" },
  "1.31": { eol: "2026-11-23", successor: "1.32 or later" },
  "1.32": { eol: "2027-04-23", successor: "1.33 or later" },
  "1.33": { eol: "2027-07-29", successor: "1.34 or later" },
  "1.34": { eol: "2027-12-02", successor: "1.35 or later" },
};

export const EOL_WARNING_MONTHS = parseInt(process.env.EOL_WARNING_MONTHS) || 6;
export const EOL_URGENT_MONTHS = parseInt(process.env.EOL_URGENT_MONTHS) || 3;
export const CERT_EXPIRY_WARNING_DAYS = parseInt(process.env.CERT_EXPIRY_WARNING_DAYS) || 30;
export const SAVINGS_PLAN_WARNING_DAYS = parseInt(process.env.SAVINGS_PLAN_WARNING_DAYS) || 60;
export const ACCESS_KEY_WARNING_DAYS = parseInt(process.env.ACCESS_KEY_WARNING_DAYS) || 90;
export const EBS_SNAPSHOT_AGE_DAYS = parseInt(process.env.EBS_SNAPSHOT_AGE_DAYS) || 180;
export const AMI_STALE_AGE_DAYS = parseInt(process.env.AMI_STALE_AGE_DAYS) || 365;
