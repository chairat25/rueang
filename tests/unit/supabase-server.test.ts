// @vitest-environment node
import { describe, it, expect, vi, beforeEach } from "vitest";
import { NextRequest } from "next/server";

// Mock next/headers
const mockCookieStore = {
  getAll: vi.fn().mockReturnValue([{ name: "sb-token", value: "mock-token" }]),
  set: vi.fn(),
};

vi.mock("next/headers", () => ({
  cookies: vi.fn().mockResolvedValue(mockCookieStore),
}));

// Mock @supabase/ssr
const mockGetUser = vi.fn();
const mockExchangeCode = vi.fn();

vi.mock("@supabase/ssr", () => ({
  createServerClient: vi.fn((_url, _key, options) => {
    // Invoke cookies callbacks to test coverage
    if (options?.cookies?.getAll) {
      options.cookies.getAll();
    }
    if (options?.cookies?.setAll) {
      options.cookies.setAll([{ name: "test", value: "123", options: {} }]);
    }

    return {
      auth: {
        getUser: mockGetUser,
        exchangeCodeForSession: mockExchangeCode,
      },
    };
  }),
}));

function createTestRequest(url: string) {
  return new NextRequest(new URL(url));
}

describe("Supabase Server & Middleware Helpers", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "test-anon-key";
    process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";
  });

  describe("createServerClient (lib/supabase/server.ts)", () => {
    it("creates server client with cookie access", async () => {
      const { createServerClient } = await import("@/lib/supabase/server");
      const client = await createServerClient();
      expect(client).toBeDefined();
    });
  });

  describe("updateSession (lib/supabase/middleware.ts)", () => {
    it("redirects unauthenticated user from protected route to /login", async () => {
      mockGetUser.mockResolvedValueOnce({ data: { user: null } });

      const { updateSession } = await import("@/lib/supabase/middleware");
      const req = createTestRequest("http://localhost:3000/topics/123");
      const response = await updateSession(req);

      expect(response.status).toBe(307); // Redirect
      expect(response.headers.get("location")).toContain("/login?returnTo=%2Ftopics%2F123");
    });

    it("allows unauthenticated user to access public routes like /login", async () => {
      mockGetUser.mockResolvedValueOnce({ data: { user: null } });

      const { updateSession } = await import("@/lib/supabase/middleware");
      const req = createTestRequest("http://localhost:3000/login");
      const response = await updateSession(req);

      expect(response.status).toBe(200); // Next
    });

    it("redirects authenticated user away from /login to home", async () => {
      mockGetUser.mockResolvedValueOnce({
        data: { user: { id: "user-123", email: "user@example.com" } },
      });

      const { updateSession } = await import("@/lib/supabase/middleware");
      const req = createTestRequest("http://localhost:3000/login");
      const response = await updateSession(req);

      expect(response.status).toBe(307);
      expect(response.headers.get("location")).toBe("http://localhost:3000/");
    });

    it("allows authenticated user to access protected routes", async () => {
      mockGetUser.mockResolvedValueOnce({
        data: { user: { id: "user-123", email: "user@example.com" } },
      });

      const { updateSession } = await import("@/lib/supabase/middleware");
      const req = createTestRequest("http://localhost:3000/topics/123");
      const response = await updateSession(req);

      expect(response.status).toBe(200);
    });
  });

  describe("Auth Callback (app/auth/callback/route.ts)", () => {
    it("exchanges code for session and redirects to next url", async () => {
      mockExchangeCode.mockResolvedValueOnce({ error: null });

      const { GET } = await import("@/app/auth/callback/route");
      const req = createTestRequest("http://localhost:3000/auth/callback?code=test-code&next=/topics");
      const response = await GET(req);

      expect(response.status).toBe(307);
      expect(response.headers.get("location")).toBe("http://localhost:3000/topics");
    });

    it("redirects to login error when code exchange fails", async () => {
      mockExchangeCode.mockResolvedValueOnce({ error: new Error("invalid code") });

      const { GET } = await import("@/app/auth/callback/route");
      const req = createTestRequest("http://localhost:3000/auth/callback?code=bad-code");
      const response = await GET(req);

      expect(response.status).toBe(307);
      expect(response.headers.get("location")).toContain("/login?error=auth_callback_failed");
    });
  });
});
