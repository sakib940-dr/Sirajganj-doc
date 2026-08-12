import { cn } from "@/lib/utils";

/** সাধারণ শিমার ব্লক — নির্দিষ্ট আকৃতির প্লেসহোল্ডার বানাতে rounded/h-/w- ক্লাস দিয়ে ব্যবহার করুন */
export default function Skeleton({ className }) {
  return <div className={cn("skeleton rounded-md", className)} />;
}
