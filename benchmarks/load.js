import { sleep } from "k6";
import { mixedApiScenario, setupTenant } from "./lib/supportnest.js";

export const options = {
  vus: 10,
  duration: "60s",
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<600"]
  }
};

export function setup() {
  return setupTenant();
}

export default function (data) {
  mixedApiScenario(data);
  sleep(0.25);
}
