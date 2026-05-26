import { handleScheduledCheck } from "./lib/handlers/scheduled.mjs";
import { handleSnsEvent } from "./lib/handlers/sns.mjs";
import { handleHealthEvent } from "./lib/handlers/health.mjs";
import { handleCloudTrailEvent } from "./lib/handlers/cloudtrail.mjs";

export const handler = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  try {
    if (event.source === "aws.events" || event["detail-type"] === "Scheduled Event") {
      return await handleScheduledCheck();
    }

    if (event.source === "aws.health") {
      return await handleHealthEvent(event);
    }

    const detailType = event["detail-type"];
    if (
      detailType === "AWS API Call via CloudTrail" ||
      detailType === "AWS Console Sign In via CloudTrail"
    ) {
      return await handleCloudTrailEvent(event);
    }

    if (event.Records && event.Records[0]?.Sns) {
      return await handleSnsEvent(event);
    }

    console.log("Unrecognized event type");
    return { statusCode: 200, body: "No message to send" };
  } catch (error) {
    console.error("Error processing event:", error);
    throw error;
  }
};
