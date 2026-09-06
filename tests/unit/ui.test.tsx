import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

describe("UI Primitives", () => {
  it("renders Button correctly with variant classes", () => {
    render(<Button variant="destructive">ลบข้อมูล</Button>);
    const button = screen.getByRole("button", { name: "ลบข้อมูล" });
    expect(button).toBeInTheDocument();
    expect(button.className).toContain("bg-destructive");
  });

  it("renders Input correctly with placeholder", () => {
    render(<Input placeholder="พิมพ์ข้อความ..." />);
    const input = screen.getByPlaceholderText("พิมพ์ข้อความ...");
    expect(input).toBeInTheDocument();
  });

  it("renders Card and CardTitle", () => {
    render(
      <Card>
        <CardTitle>หัวข้อการ์ด</CardTitle>
      </Card>
    );
    expect(screen.getByText("หัวข้อการ์ด")).toBeInTheDocument();
  });

  it("renders Skeleton with animation class", () => {
    const { container } = render(<Skeleton className="h-4 w-20" />);
    expect(container.firstChild).toHaveClass("animate-pulse");
  });

  it("merges classnames with cn() utility", () => {
    const result = cn("px-2 py-1", "px-4", { "text-red-500": true });
    expect(result).toBe("py-1 px-4 text-red-500");
  });
});
