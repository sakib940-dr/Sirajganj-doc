import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { registerSW } from "virtual:pwa-register";
import App from "./App.jsx";
import { AuthProvider } from "./context/AuthContext.jsx";
import { PWAInstallProvider } from "./context/PWAInstallContext.jsx";
import "./index.css";

// প্রোডাকশন বিল্ডে সার্ভিস ওয়ার্কার রেজিস্টার করা হয় — এটা PWA "installability"
// criteria-র একটা অংশ (manifest + HTTPS + registered service worker)। কোনো
// "নতুন ভার্সন এসেছে, রিফ্রেশ করুন" UI ইচ্ছাকৃতভাবে বানানো হয়নি (স্কোপ শুধু
// ইনস্টল-প্রম্পট এক্সপেরিয়েন্স পর্যন্তই), নতুন ভার্সন এমনিতেই পরবর্তী ভিজিটে
// স্বয়ংক্রিয়ভাবে অ্যাক্টিভেট হয়ে যাবে।
if ("serviceWorker" in navigator) {
  registerSW({ immediate: true });
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <PWAInstallProvider>
          <App />
        </PWAInstallProvider>
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
);
