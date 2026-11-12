import type { Metadata } from "next";
import "../globals.css";

export const metadata: Metadata = {
  title: "UPI ID 생성·검증",
  description: "UPI ID(VPA) 형식 검증, 후보 생성, 결제 딥링크 생성",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
