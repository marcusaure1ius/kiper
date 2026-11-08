import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { AppShell } from "@/components/AppShell";
import { ThemeProvider } from "@/components/theme";

const inter = Inter({
  subsets: ["latin", "cyrillic"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Кипер — учёт подписок",
  description: "Трекер подписок: ближайшие списания, аналитика и бюджет месяца.",
  applicationName: "Кипер",
  appleWebApp: { capable: true, title: "Кипер", statusBarStyle: "default" },
  icons: {
    icon: [{ url: "/icons/icon-192.png", sizes: "192x192", type: "image/png" }],
    apple: [{ url: "/icons/icon-180.png", sizes: "180x180", type: "image/png" }],
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fbf9f6" },
    { media: "(prefers-color-scheme: dark)", color: "#0b0818" },
  ],
};

// Applies stored theme/palette before first paint (no flash).
const bootScript = `(function(){try{var m=localStorage.getItem('kiper.theme')||'auto';var p=localStorage.getItem('kiper.palette')||'lavender';var dark=m==='dark'||(m==='auto'&&matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',dark);var a={lavender:[10902785,9403647],aurora:[961406,4054184],sunset:[15224890,16749413],ocean:[1998297,5219071],graphite:[4869740,13085651],iris:[13721802,16738229]};var c=(a[p]||a.lavender)[dark?1:0];document.documentElement.style.setProperty('--accent','#'+c.toString(16).padStart(6,'0'));}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: bootScript }} />
      </head>
      <body className={inter.variable}>
        <ThemeProvider>
          <AppShell>{children}</AppShell>
        </ThemeProvider>
      </body>
    </html>
  );
}
