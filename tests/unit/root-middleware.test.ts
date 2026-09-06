// @vitest-environment node
import { describe, it, expect, vi } from "vitest";
import { NextRequest } from "next/server";

vi.mock("@/lib/supabase/middleware", () => ({
  updateSession: vi.fn().mockResolvedValue({ status: 200 }),
}));

describe("Root Middleware (middleware.ts)", () => {
  it("invokes updateSession on request", async () => {
    const { middleware } = await import("@/middleware");
    const req = new NextRequest(new URL("http://localhost:3000/"));
    const res = await middleware(req);
    expect(res).toBeDefined();
    expect(res.status).toBe(200);
  });
});
