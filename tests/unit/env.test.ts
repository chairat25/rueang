import { describe, it, expect, beforeEach, vi } from "vitest";

describe("Environment Variables Validation", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    vi.resetModules();
    process.env = { ...originalEnv };
  });

  describe("Public Env (lib/env.ts)", () => {
    it("fails with clear error message when NEXT_PUBLIC_SUPABASE_URL is missing", async () => {
      delete process.env.NEXT_PUBLIC_SUPABASE_URL;
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "test-anon-key";

      await expect(import("@/lib/env")).rejects.toThrow(/NEXT_PUBLIC_SUPABASE_URL/);
    });

    it("fails with clear error message when NEXT_PUBLIC_SUPABASE_ANON_KEY is missing", async () => {
      process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
      delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

      await expect(import("@/lib/env")).rejects.toThrow(/NEXT_PUBLIC_SUPABASE_ANON_KEY/);
    });

    it("passes and exports validated env when all required variables are set", async () => {
      process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "test-anon-key";
      process.env.NEXT_PUBLIC_APP_URL = "http://localhost:3000";

      const { env } = await import("@/lib/env");
      expect(env.NEXT_PUBLIC_SUPABASE_URL).toBe("https://example.supabase.co");
      expect(env.NEXT_PUBLIC_SUPABASE_ANON_KEY).toBe("test-anon-key");
      expect(env.NEXT_PUBLIC_APP_URL).toBe("http://localhost:3000");
    });
  });

  describe("Server Env (lib/env.server.ts)", () => {
    it("fails with clear error message when SUPABASE_SERVICE_ROLE_KEY is missing", async () => {
      delete process.env.SUPABASE_SERVICE_ROLE_KEY;

      await expect(import("@/lib/env.server")).rejects.toThrow(/SUPABASE_SERVICE_ROLE_KEY/);
    });

    it("passes and exports validated server env when SUPABASE_SERVICE_ROLE_KEY is set", async () => {
      process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";

      const { envServer } = await import("@/lib/env.server");
      expect(envServer.SUPABASE_SERVICE_ROLE_KEY).toBe("test-service-role-key");
    });
  });
});
