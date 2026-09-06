import type { ReactNode } from "react";
import Link from "next/link";
import { Folder, Compass, Search } from "lucide-react";

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen flex flex-col bg-background text-foreground pb-20">
      <header className="sticky top-0 z-40 border-b border-border bg-background/80 backdrop-blur-md px-4 h-14 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 text-primary font-bold text-sm">
            ร
          </span>
          <h1 className="font-semibold text-base">เรื่อง (Rueang)</h1>
        </div>
      </header>

      <main className="flex-1 max-w-lg mx-auto w-full p-4">{children}</main>

      {/* Mobile Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 z-50 border-t border-border bg-card/90 backdrop-blur-md h-16 flex items-center justify-around px-4 max-w-lg mx-auto">
        <Link
          href="/"
          className="flex flex-col items-center gap-1 text-xs text-primary transition-colors"
        >
          <Folder className="h-5 w-5" />
          <span>เรื่องทั้งหมด</span>
        </Link>
        <Link
          href="/search"
          className="flex flex-col items-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
        >
          <Search className="h-5 w-5" />
          <span>ค้นหา</span>
        </Link>
        <Link
          href="/share"
          className="flex flex-col items-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
        >
          <Compass className="h-5 w-5" />
          <span>เก็บเรื่อง</span>
        </Link>
      </nav>
    </div>
  );
}
