import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";
import { validateUrl } from "@/components/admin/cms/validators.js";

const FIELDS = [
  { key: "hero_title", label: "হিরো শিরোনাম", type: "text", maxLength: 100, placeholder: "যেমন: আপনার এলাকার সবচেয়ে বড় অনলাইন বাজার" },
  { key: "hero_subtitle", label: "হিরো সাব-টেক্সট", type: "textarea", rows: 3, maxLength: 220, placeholder: "শিরোনামের নিচে ছোট বর্ণনা" },
  { key: "hero_image_url", label: "হিরো ব্যাকগ্রাউন্ড/প্রধান ছবি", type: "image", folder: "hero", aspect: "wide" },
  { key: "hero_button_text", label: "বাটনের লেখা", type: "text", maxLength: 30, placeholder: "যেমন: এখনই কেনাকাটা করুন" },
  { key: "hero_button_link", label: "বাটনের লিংক", type: "text", placeholder: "/search অথবা https://...", validate: validateUrl },
];

export default function HeroTab({ values, saveFields, clearFields }) {
  return (
    <SettingsFieldGroup
      title="হোমপেজ হিরো সেকশন"
      description="হোমপেজের সবচেয়ে উপরের প্রধান অংশ — শিরোনাম, ছবি ও কল-টু-অ্যাকশন বাটন।"
      fields={FIELDS}
      values={values}
      onSave={saveFields}
      onClearField={(key) => clearFields([key])}
    />
  );
}
