import { test, expect } from "@playwright/test";

test.describe("Smoke Test — Unauthenticated User", () => {
  test("redirects unauthenticated user from home to /login", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/login/);
    await expect(page.getByText("Rueang (เรื่อง)")).toBeVisible();
    await expect(page.getByText("เข้าสู่ระบบด้วย Google")).toBeVisible();
  });
});
