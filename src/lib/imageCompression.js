/**
 * ব্রাউজারে ছবি লোড করে একটি HTMLImageElement রিটার্ন করে।
 */
function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => resolve({ img, url });
    img.onerror = (err) => {
      URL.revokeObjectURL(url);
      reject(err);
    };
    img.src = url;
  });
}

function canvasToBlob(canvas, quality) {
  return new Promise((resolve) => {
    canvas.toBlob((blob) => resolve(blob), "image/jpeg", quality);
  });
}

/**
 * ছবির ফাইল একটি নির্দিষ্ট সাইজ রেঞ্জের (KB) মধ্যে কমপ্রেস করে।
 * ক্যানভাসে এঁকে JPEG quality কমিয়ে এবং প্রয়োজনে dimension ছোট করে
 * টার্গেট সাইজে পৌঁছানোর চেষ্টা করে।
 *
 * - ইনপুট ফাইল ইতিমধ্যে টার্গেট রেঞ্জের মধ্যে বা তার চেয়ে ছোট হলে,
 *   অপরিবর্তিত ফাইলটাই ফেরত দেয় (অহেতুক কোয়ালিটি নষ্ট করা হয় না)।
 * - টার্গেট মিনিমামের চেয়ে বড় রেজাল্ট পাওয়া গেলেও, ম্যাক্সিমামের নিচে
 *   নামানোই মূল লক্ষ্য (খুব ছোট/সাধারণ ছবিতে ১০০ KB-এ নাও পৌঁছাতে পারে)।
 *
 * @param {File} file
 * @param {{ targetMinKB?: number, targetMaxKB?: number }} options
 * @returns {Promise<File>}
 */
export async function compressImageToRange(file, { targetMinKB = 100, targetMaxKB = 200 } = {}) {
  if (!file.type.startsWith("image/")) return file;

  const targetMaxBytes = targetMaxKB * 1024;
  const targetMinBytes = targetMinKB * 1024;

  // ইতিমধ্যে টার্গেটের মধ্যে বা তার চেয়ে ছোট — কমপ্রেস করার দরকার নেই
  if (file.size <= targetMaxBytes) return file;

  // GIF/animated ছবি ক্যানভাসে আঁকলে অ্যানিমেশন নষ্ট হয়ে যায় — স্কিপ করা হচ্ছে
  if (file.type === "image/gif") return file;

  let objectUrl;
  try {
    const { img, url } = await loadImage(file);
    objectUrl = url;

    let { naturalWidth: width, naturalHeight: height } = img;
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");

    let bestBlob = null;
    let quality = 0.85;
    let attempts = 0;
    const MAX_ATTEMPTS = 12;

    while (attempts < MAX_ATTEMPTS) {
      attempts += 1;
      canvas.width = width;
      canvas.height = height;
      ctx.clearRect(0, 0, width, height);
      // সাদা ব্যাকগ্রাউন্ড (PNG-এর transparent অংশ কালো না হয়ে যাওয়ার জন্য)
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, width, height);
      ctx.drawImage(img, 0, 0, width, height);

      // eslint-disable-next-line no-await-in-loop
      const blob = await canvasToBlob(canvas, quality);
      if (!blob) break;

      bestBlob = blob;

      if (blob.size <= targetMaxBytes) {
        // টার্গেট রেঞ্জে পৌঁছে গেছে
        if (blob.size >= targetMinBytes || quality >= 0.92) break;
        // এখনো মিনিমামের চেয়ে ছোট — কোয়ালিটি সামান্য বাড়িয়ে আবার চেষ্টা
        quality = Math.min(0.95, quality + 0.07);
        continue;
      }

      if (quality > 0.4) {
        quality -= 0.1;
      } else {
        // কোয়ালিটি কমিয়ে কাজ না হলে dimension ছোট করা হচ্ছে
        width = Math.round(width * 0.85);
        height = Math.round(height * 0.85);
        quality = 0.75;
      }
    }

    if (!bestBlob) return file;

    const newName = file.name.replace(/\.[^.]+$/, "") + ".jpg";
    return new File([bestBlob], newName, { type: "image/jpeg", lastModified: Date.now() });
  } finally {
    if (objectUrl) URL.revokeObjectURL(objectUrl);
  }
}
