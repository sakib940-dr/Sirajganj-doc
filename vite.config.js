import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";
import path from "path";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      // "prompt" — ব্রাউজারের নিজস্ব auto-update reload হয় না, আমাদের নিজস্ব
      // ইনস্টল-প্রম্পট UI (InstallPromptProvider) সম্পূর্ণ নিয়ন্ত্রণ করে কবে
      // ইনস্টল সাজেশন দেখানো হবে — তাই registerType "prompt" রাখা হয়েছে
      registerType: "prompt",
      includeAssets: ["favicon.svg", "apple-touch-icon.png"],
      manifest: {
        name: "সিরাজগঞ্জ ডাক্তার — ডাক্তার ও স্বাস্থ্যসেবা",
        short_name: "সিরাজগঞ্জ ডাক্তার",
        description: "সিরাজগঞ্জের ডাক্তার, চেম্বার, হাসপাতাল, রক্তদাতা ও অ্যাম্বুলেন্স খুঁজুন।",
        lang: "bn",
        start_url: "/",
        scope: "/",
        display: "standalone",
        theme_color: "#0b4f4a",
        background_color: "#ffffff",
        icons: [
          { src: "/pwa-192x192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: "/pwa-512x512.png", sizes: "512x512", type: "image/png", purpose: "any" },
          { src: "/pwa-maskable-512x512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        ],
      },
      workbox: {
        // শুধু build output cache করে অ্যাপটাকে ইনস্টলযোগ্য/অফলাইন-শেল করার জন্য
        // ন্যূনতম সার্ভিস ওয়ার্কার — API/ডাটা কল (Supabase) cache করা হয় না,
        // যাতে ইউজার সবসময় সবশেষ পণ্য/দোকানের তথ্য দেখেন
        globPatterns: ["**/*.{js,css,html,svg,png,ico}"],
        navigateFallback: "/index.html",
        cleanupOutdatedCaches: true,
      },
      devOptions: {
        enabled: false,
      },
    }),
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 5173,
  },
});
