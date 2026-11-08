import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Кипер — учёт подписок",
    short_name: "Кипер",
    description: "Трекер подписок: ближайшие списания, аналитика и бюджет месяца.",
    start_url: "/",
    display: "standalone",
    background_color: "#fbf9f6",
    theme_color: "#fbf9f6",
    lang: "ru",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
    ],
  };
}
