import http from "k6/http";
import { check, fail } from "k6";

const DEFAULT_BASE_URL = "http://127.0.0.1:3000";

export function baseUrl() {
  return __ENV.BASE_URL || DEFAULT_BASE_URL;
}

export function setupTenant() {
  const suffix = uniqueSuffix();
  const bootstrapResponse = http.post(
    `${baseUrl()}/v1/organizations`,
    JSON.stringify({
      organization: {
        name: "Benchmark Tenant",
        slug: `bench-${suffix}`,
        plan: "growth",
        seat_limit: 100,
        inbox_limit: 10,
        ticket_limit: 100000
      },
      owner: {
        email: `owner-${suffix}@bench.test`,
        full_name: "Benchmark Owner"
      }
    }),
    jsonOptions(`bench-bootstrap-${suffix}`)
  );

  check(bootstrapResponse, {
    "bootstrap returns 201": (response) => response.status === 201
  });

  if (bootstrapResponse.status !== 201) {
    fail(`benchmark bootstrap failed: ${bootstrapResponse.status} ${bootstrapResponse.body}`);
  }

  const token = bootstrapResponse.json("owner.api_token");
  const seedTicketResponse = createTicket(token, suffix, "seed");

  check(seedTicketResponse, {
    "seed ticket returns 201": (response) => response.status === 201
  });

  if (seedTicketResponse.status !== 201) {
    fail(`benchmark seed ticket failed: ${seedTicketResponse.status} ${seedTicketResponse.body}`);
  }

  return {
    token,
    seededTicketId: seedTicketResponse.json("ticket.id")
  };
}

export function smokeScenario(data) {
  const organizationResponse = http.get(
    `${baseUrl()}/v1/organization`,
    authOptions(data.token, correlationId("smoke-org"))
  );
  const ticketReadResponse = http.get(
    `${baseUrl()}/v1/tickets/${data.seededTicketId}`,
    authOptions(data.token, correlationId("smoke-ticket-read"))
  );
  const ticketCreateResponse = createTicket(data.token, `vu${__VU}`, `iter${__ITER}`);

  check(organizationResponse, {
    "organization read returns 200": (response) => response.status === 200
  });
  check(ticketReadResponse, {
    "ticket read returns 200": (response) => response.status === 200
  });
  check(ticketCreateResponse, {
    "ticket create returns 201": (response) => response.status === 201
  });
}

export function mixedApiScenario(data) {
  const selector = Math.random();

  if (selector < 0.20) {
    const response = http.get(
      `${baseUrl()}/v1/organization`,
      authOptions(data.token, correlationId("org-read"))
    );

    check(response, {
      "organization read returns 200": (result) => result.status === 200
    });

    return;
  }

  if (selector < 0.75) {
    const response = http.get(
      `${baseUrl()}/v1/tickets/${data.seededTicketId}`,
      authOptions(data.token, correlationId("ticket-read"))
    );

    check(response, {
      "ticket read returns 200": (result) => result.status === 200
    });

    return;
  }

  const response = createTicket(data.token, `vu${__VU}`, `iter${__ITER}`);

  check(response, {
    "ticket create returns 201": (result) => result.status === 201
  });
}

function createTicket(token, prefix, suffix) {
  return http.post(
    `${baseUrl()}/v1/tickets`,
    JSON.stringify({
      ticket: {
        subject: `Benchmark issue ${prefix}-${suffix}`,
        description: "Benchmark-generated ticket exercising the authenticated write path.",
        requester_name: "Benchmark Customer",
        requester_email: `customer-${prefix}-${suffix}@bench.test`,
        inbox: "general",
        priority: "normal"
      }
    }),
    authOptions(token, correlationId(`ticket-create-${prefix}-${suffix}`))
  );
}

function jsonOptions(correlation) {
  return {
    headers: {
      "Content-Type": "application/json",
      "X-Correlation-ID": correlation
    }
  };
}

function authOptions(token, correlation) {
  return {
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      "X-Correlation-ID": correlation
    }
  };
}

function correlationId(prefix) {
  const vu = typeof __VU === "undefined" ? 0 : __VU;
  const iter = typeof __ITER === "undefined" ? 0 : __ITER;

  return `bench-${prefix}-${vu}-${iter}`;
}

function uniqueSuffix() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
