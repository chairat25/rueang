import { Card, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";

export default function HomePage() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold tracking-tight">เรื่องของคุณ</h2>
        <Button size="sm" className="gap-1 rounded-xl">
          <Plus className="h-4 w-4" />
          <span>สร้างเรื่องใหม่</span>
        </Button>
      </div>

      <Card className="border-dashed border-border/80 bg-card/40 text-center py-12">
        <CardHeader className="items-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-muted text-2xl mb-2">
            📂
          </div>
          <CardTitle className="text-base font-medium">ยังไม่มีเรื่องที่บันทึกไว้</CardTitle>
          <CardDescription className="text-xs text-muted-foreground max-w-xs">
            เริ่มต้นสร้างเรื่องแรกของคุณ หรือแชร์ลิงก์จาก TikTok / YouTube เข้ามาได้เลย
          </CardDescription>
        </CardHeader>
      </Card>
    </div>
  );
}
