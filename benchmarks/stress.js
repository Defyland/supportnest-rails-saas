import { sleep } from "k6";
import { mixedApiScenario, setupTenant } from "./lib/supportnest.js";

export const options = {
  stages: [
    { duration: "20s", target: 10 },
    { duration: "20s", target: 20 },
    { duration: "20s", target: 30 },
    { duration: "20s", target: 0 }
  ],
  thresholds: {
    http_req_failed: ["rate<0.05"]
  }
};

export function setup() {
  return setupTenant();
}

export default function (data) {
  mixedApiScenario(data);
  sleep(0.1);
}
