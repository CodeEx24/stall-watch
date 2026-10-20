import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Stall Watch",
  description: "Finish selections and stalled-project alerts for home builders.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
