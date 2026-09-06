import type { Metadata, Viewport } from "next";
import { IBM_Plex_Sans_Thai } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";

const ibmPlexSansThai = IBM_Plex_Sans_Thai({
  weight: ["300", "400", "500", "600", "700"],
  subsets: ["thai", "latin"],
  variable: "--font-ibm-plex-sans-thai",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Rueang (เรื่อง) — กล่องเก็บเรื่องและแผนเที่ยว",
  description: "กล่องเก็บเรื่องที่แชร์เข้ามาจากแอปได้ใน 2 แตะ พร้อมโหมดวางแผนเที่ยว",
  manifest: "/manifest.json",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  themeColor: "#0f1115",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="th" className={`dark ${ibmPlexSansThai.variable}`}>
      <body className="font-sans antialiased bg-background text-foreground min-h-[100dvh]">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
