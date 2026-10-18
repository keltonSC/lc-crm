import type { MetadataRoute } from "next";

// Permite "Adicionar à tela inicial" no celular: o CRM abre como app.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "LC CRM",
    short_name: "LC CRM",
    description: "Leads, funil e agenda da LC Imóveis",
    start_url: "/leads",
    display: "standalone",
    background_color: "#f7f6f4",
    theme_color: "#e2561d",
    icons: [
      { src: "/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
      { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
    ],
  };
}
