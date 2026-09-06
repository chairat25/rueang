import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import LoginPage from "@/app/(auth)/login/page";

// Mock Supabase client
const mockSignInWithOtp = vi.fn().mockResolvedValue({ error: null });
const mockSignInWithOAuth = vi.fn().mockResolvedValue({ error: null });

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    auth: {
      signInWithOAuth: mockSignInWithOAuth,
      signInWithOtp: mockSignInWithOtp,
    },
  }),
}));

// Mock next/navigation
vi.mock("next/navigation", () => ({
  useSearchParams: () => new URLSearchParams(),
}));

describe("LoginPage Component", () => {
  it("renders Thai login UI properly", () => {
    render(<LoginPage />);

    expect(screen.getByText("Rueang (เรื่อง)")).toBeInTheDocument();
    expect(
      screen.getByText("กล่องเก็บเรื่องและแผนเที่ยวในที่เดียว")
    ).toBeInTheDocument();
    expect(screen.getByText("เข้าสู่ระบบด้วย Google")).toBeInTheDocument();
    expect(screen.getByText("ส่งลิงก์เข้าสู่ระบบ")).toBeInTheDocument();
  });

  it("validates invalid email input on form submission", () => {
    render(<LoginPage />);

    const input = screen.getByLabelText("อีเมล");
    const form = input.closest("form")!;

    fireEvent.change(input, { target: { value: "invalid-email" } });
    fireEvent.submit(form);

    expect(screen.getByRole("alert")).toHaveTextContent(
      "กรุณาระบุอีเมลที่ถูกต้อง"
    );
  });

  it("submits magic link with valid email", async () => {
    render(<LoginPage />);

    const input = screen.getByLabelText("อีเมล");
    const form = input.closest("form")!;

    fireEvent.change(input, { target: { value: "user@example.com" } });
    fireEvent.submit(form);

    await waitFor(() => {
      expect(mockSignInWithOtp).toHaveBeenCalledWith({
        email: "user@example.com",
        options: expect.objectContaining({
          emailRedirectTo: expect.stringContaining("/auth/callback"),
        }),
      });
    });

    expect(
      screen.getByText(/เราได้ส่ง Magic Link ไปยังอีเมล/i)
    ).toBeInTheDocument();
  });
});
