import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    baseline: {
      executor: "ramping-vus",
      startVUs: 1,
      stages: [
        { duration: "2m", target: 10 },
        { duration: "5m", target: 25 },
        { duration: "2m", target: 0 },
      ],
      gracefulRampDown: "30s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<500", "p(99)<1000"],
    checks: ["rate>0.99"],
  },
};

const baseUrl = __ENV.BASE_URL;
if (!baseUrl) {
  throw new Error("BASE_URL is required");
}

export default function () {
  const response = http.get(`${baseUrl}/health`, {
    tags: { endpoint: "health" },
    timeout: "5s",
  });
  check(response, {
    "status is successful": (r) => r.status >= 200 && r.status < 400,
  });
  sleep(1);
}
