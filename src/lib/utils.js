import { clsx } from "clsx";
import { twMerge } from "tailwind-merge";

/** Tailwind class merge helper (shadcn/ui pattern) */
export function cn(...inputs) {
  return twMerge(clsx(inputs));
}

/** বাংলা/ইংরেজি টেক্সট থেকে URL-friendly slug তৈরি করে */
export function slugify(text = "") {
  return text
    .toString()
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^\u0980-\u09FFa-z0-9-]/g, "")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

/** সংখ্যাকে বাংলা মুদ্রা ফরম্যাটে দেখায়, যেমন ১,২৫০ টাকা */
export function formatPriceBn(amount) {
  if (amount === null || amount === undefined) return "";
  const bnDigits = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"];
  const formatted = Number(amount).toLocaleString("en-IN");
  const converted = formatted.replace(/\d/g, (d) => bnDigits[d]);
  return `৳ ${converted}`;
}

/**
 * ডাক্তার প্রোফাইলের ডিসকাউন্ট প্রয়োগ করে আসল ও ছাড়কৃত কনসালটেশন ফি বের করে।
 * @param {{ price: number, discount_type?: 'none'|'fixed'|'percentage', discount_value?: number }} product
 * @returns {{ hasDiscount: boolean, originalPrice: number, finalPrice: number, percentOff: number }}
 */
export function getDiscountedPrice(product) {
  const price = Number(product?.price) || 0;
  const type = product?.discount_type || "none";
  const value = Number(product?.discount_value) || 0;

  if (!product || type === "none" || value <= 0) {
    return { hasDiscount: false, originalPrice: price, finalPrice: price, percentOff: 0 };
  }

  let finalPrice = price;
  if (type === "percentage") {
    finalPrice = price - (price * Math.min(value, 100)) / 100;
  } else if (type === "fixed") {
    finalPrice = price - value;
  }
  finalPrice = Math.max(0, Math.round(finalPrice * 100) / 100);

  const percentOff = price > 0 ? Math.round(((price - finalPrice) / price) * 100) : 0;

  return {
    hasDiscount: finalPrice < price,
    originalPrice: price,
    finalPrice,
    percentOff,
  };
}

/** তারিখকে বাংলা লোকেলে ফরম্যাট করে */
export function formatDateBn(dateString) {
  if (!dateString) return "";
  return new Date(dateString).toLocaleDateString("bn-BD", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}
