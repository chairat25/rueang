"use client";

import { useState, useTransition, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";

function LoginForm() {
  const searchParams = useSearchParams();
  const urlError = searchParams.get("error");
  const returnTo = searchParams.get("returnTo") || "/";

  const [email, setEmail] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(
    urlError === "auth_callback_failed"
      ? "การยืนยันตัวตนไม่สำเร็จ กรุณาลองใหม่อีกครั้ง"
      : null
  );
  const [isSuccess, setIsSuccess] = useState(false);
  const [isPending, startTransition] = useTransition();

  const supabase = createClient();

  const handleGoogleLogin = async () => {
    setErrorMessage(null);
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(returnTo)}`,
        },
      });
      if (error) {
        console.error("[Login Google]", error);
        setErrorMessage("ไม่สามารถเชื่อมต่อ Google ได้ กรุณาลองใหม่อีกครั้ง");
      }
    } catch (err) {
      console.error("[Login Google Catch]", err);
      setErrorMessage("เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง");
    }
  };

  const handleMagicLinkLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    const trimmedEmail = email.trim();
    if (!trimmedEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      setErrorMessage("กรุณาระบุอีเมลที่ถูกต้อง");
      return;
    }

    startTransition(async () => {
      try {
        const { error } = await supabase.auth.signInWithOtp({
          email: trimmedEmail,
          options: {
            emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(returnTo)}`,
          },
        });

        if (error) {
          console.error("[Login MagicLink]", error);
          setErrorMessage("ส่งลิงก์ไม่สำเร็จ กรุณาตรวจสอบอีเมลแล้วลองใหม่");
        } else {
          setIsSuccess(true);
        }
      } catch (err) {
        console.error("[Login MagicLink Catch]", err);
        setErrorMessage("เกิดข้อผิดพลาดในการส่งลิงก์ กรุณาลองใหม่อีกครั้ง");
      }
    });
  };

  return (
    <main className="min-h-screen flex items-center justify-center p-4 bg-background">
      <Card className="w-full max-w-md border-border/80 bg-card/90 backdrop-blur-sm shadow-xl">
        <CardHeader className="text-center pb-6">
          <div className="mx-auto mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary text-2xl font-bold border border-primary/20">
            ร
          </div>
          <CardTitle className="text-2xl font-bold tracking-tight">
            Rueang (เรื่อง)
          </CardTitle>
          <CardDescription className="text-muted-foreground mt-1 text-sm">
            กล่องเก็บเรื่องและแผนเที่ยวในที่เดียว
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-4">
          {errorMessage && (
            <div
              role="alert"
              className="p-3 rounded-lg bg-destructive/10 border border-destructive/20 text-destructive text-sm"
            >
              {errorMessage}
            </div>
          )}

          {isSuccess ? (
            <div className="space-y-4 text-center py-4">
              <div className="p-4 rounded-xl bg-primary/10 border border-primary/20 text-foreground text-sm leading-relaxed">
                ✉️ เราได้ส่ง Magic Link ไปยังอีเมล <strong>{email}</strong> แล้ว
                <br />
                กรุณาเปิดอีเมลเพื่อเข้าสู่ระบบ
              </div>
              <Button
                variant="outline"
                className="w-full"
                onClick={() => setIsSuccess(false)}
              >
                ใช้อีเมลอื่น
              </Button>
            </div>
          ) : (
            <>
              <Button
                type="button"
                variant="secondary"
                className="w-full h-11 font-medium flex items-center justify-center gap-2 border border-border"
                onClick={handleGoogleLogin}
              >
                <svg className="w-4 h-4" viewBox="0 0 24 24">
                  <path
                    fill="currentColor"
                    d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                  />
                  <path
                    fill="currentColor"
                    d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  />
                  <path
                    fill="currentColor"
                    d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                  />
                  <path
                    fill="currentColor"
                    d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                  />
                </svg>
                เข้าสู่ระบบด้วย Google
              </Button>

              <div className="relative my-4 text-center">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-border" />
                </div>
                <span className="relative bg-card px-3 text-xs text-muted-foreground">
                  หรือเข้าสู่ระบบด้วย Magic Link
                </span>
              </div>

              <form onSubmit={handleMagicLinkLogin} className="space-y-3">
                <div className="space-y-1">
                  <Input
                    type="email"
                    placeholder="name@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    disabled={isPending}
                    aria-label="อีเมล"
                    required
                  />
                </div>
                <Button
                  type="submit"
                  className="w-full h-11"
                  disabled={isPending}
                >
                  {isPending ? "กำลังส่งลิงก์..." : "ส่งลิงก์เข้าสู่ระบบ"}
                </Button>
              </form>
            </>
          )}
        </CardContent>
      </Card>
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center text-muted-foreground text-sm">
          กำลังโหลด...
        </div>
      }
    >
      <LoginForm />
    </Suspense>
  );
}
