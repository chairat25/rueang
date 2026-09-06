import { describe, it, expect } from "vitest";
import { execSync } from "child_process";

describe("Database & RLS Integration Tests", () => {
  it(
    "passes all schema smoke tests and RLS policy rules via PostgreSQL test harness",
    () => {
      const output = execSync("./scripts/test-db.sh", {
        encoding: "utf-8",
        stdio: ["pipe", "pipe", "pipe"],
      });

      expect(output).toContain("tables_without_rls");
      expect(output).toContain("anon_policies");
      expect(output).toContain(
        "All database and RLS schema tests executed successfully!"
      );
    },
    30000
  );
});
