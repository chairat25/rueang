import { describe, it, expect, vi, beforeEach } from "vitest";

describe("Supabase Clients Initialization", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "test-anon-key";
    process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-role-key";
  });

  it("creates browser client successfully", async () => {
    const { createClient } = await import("@/lib/supabase/client");
    const client = createClient();
    expect(client).toBeDefined();
    expect(typeof client.from).toBe("function");
    expect(typeof client.auth.getUser).toBe("function");
  });

  it("creates admin client successfully with service role", async () => {
    const { createAdminClient } = await import("@/lib/supabase/admin");
    const adminClient = createAdminClient();
    expect(adminClient).toBeDefined();
    expect(typeof adminClient.from).toBe("function");
  });
});
