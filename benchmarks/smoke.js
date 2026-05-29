import http from "k6/http";
import { sleep } from "k6";
import { setupTenant, smokeScenario } from "./lib/supportnest.js";

export const options = {
  vus: 2,
  duration: "30s",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<400"]
  }
};

export function setup() {
  return setupTenant();
}

export default function (data) {
  smokeScenario(data);
  sleep(1);
}
