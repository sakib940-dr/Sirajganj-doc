import { useEffect, useState } from "react";
import { Flame } from "lucide-react";

const MIN_VIEWERS = 10;
const MAX_VIEWERS = 30;
const MIN_INTERVAL_MS = 4000;
const MAX_INTERVAL_MS = 9000;

function randomInRange(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function nextIntervalMs() {
  return randomInRange(MIN_INTERVAL_MS, MAX_INTERVAL_MS);
}

// এই মুহূর্তে কতজন ডাক্তার প্রোফাইলটি দেখছেন — এটি নির্দিষ্ট বাস্তব ডেটা নয়, বরং একটি
// realistic-looking সংখ্যা (১০-৩০ এর মধ্যে) যা কিছুক্ষণ পরপর ছোট ছোট পরিবর্তনে
// ওঠানামা করে (সম্পূর্ণ এলোমেলো লাফ না দিয়ে), যাতে আসল মনে হয়।
export default function CurrentViewersBadge({ productId }) {
  const [count, setCount] = useState(() => randomInRange(MIN_VIEWERS, MAX_VIEWERS));

  useEffect(() => {
    // ডাক্তার প্রোফাইল পাল্টালে নতুন করে শুরু হবে
    setCount(randomInRange(MIN_VIEWERS, MAX_VIEWERS));
  }, [productId]);

  useEffect(() => {
    let timeoutId;

    const tick = () => {
      setCount((prev) => {
        const delta = randomInRange(-3, 3);
        const next = prev + delta;
        return Math.min(MAX_VIEWERS, Math.max(MIN_VIEWERS, next));
      });
      timeoutId = setTimeout(tick, nextIntervalMs());
    };

    timeoutId = setTimeout(tick, nextIntervalMs());
    return () => clearTimeout(timeoutId);
  }, [productId]);

  return (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-destructive/10 px-3 py-1 text-xs font-medium text-destructive">
      <Flame className="h-3.5 w-3.5" />
      এই মুহূর্তে {count} জন দেখছেন
    </span>
  );
}
