import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Providers } from "@/components/providers";
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card";
import HomePage from "@/app/(app)/page";

describe("Additional Components & Views", () => {
  it("renders Providers component with children", () => {
    render(
      <Providers>
        <div data-testid="child">Test Child</div>
      </Providers>
    );
    expect(screen.getByTestId("child")).toBeInTheDocument();
  });

  it("renders Card with all subcomponents", () => {
    render(
      <Card>
        <CardHeader>
          <CardTitle>หัวข้อ</CardTitle>
          <CardDescription>คำอธิบาย</CardDescription>
        </CardHeader>
        <CardContent>
          <p>เนื้อหา</p>
        </CardContent>
        <CardFooter>
          <p>ส่วนท้าย</p>
        </CardFooter>
      </Card>
    );

    expect(screen.getByText("หัวข้อ")).toBeInTheDocument();
    expect(screen.getByText("คำอธิบาย")).toBeInTheDocument();
    expect(screen.getByText("เนื้อหา")).toBeInTheDocument();
    expect(screen.getByText("ส่วนท้าย")).toBeInTheDocument();
  });

  it("renders HomePage with Thai empty state and create button", () => {
    render(<HomePage />);
    expect(screen.getByText("เรื่องของคุณ")).toBeInTheDocument();
    expect(screen.getByText("สร้างเรื่องใหม่")).toBeInTheDocument();
    expect(screen.getByText("ยังไม่มีเรื่องที่บันทึกไว้")).toBeInTheDocument();
  });
});
