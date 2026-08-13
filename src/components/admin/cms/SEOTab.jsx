import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";

const FIELDS = [
  {
    key: "seo_meta_title",
    label: "SEO মেটা টাইটেল",
    type: "text",
    maxLength: 60,
    placeholder: "যেমন: সিরাজগঞ্জ ডাক্তার — ডাক্তার ও স্বাস্থ্যসেবা",
    help: "সার্চ ইঞ্জিনে (গুগল) এই টেক্সটটি পেজ টাইটেল হিসেবে দেখাবে। ৬০ অক্ষরের মধ্যে রাখুন।",
  },
  {
    key: "seo_meta_description",
    label: "SEO মেটা ডেসক্রিপশন",
    type: "textarea",
    rows: 3,
    maxLength: 160,
    placeholder: "সার্চ রেজাল্টে টাইটেলের নিচে দেখানো সংক্ষিপ্ত বর্ণনা",
    help: "১৬০ অক্ষরের মধ্যে সংক্ষিপ্ত ও আকর্ষণীয় বর্ণনা দিন।",
  },
  {
    key: "seo_meta_keywords",
    label: "SEO কীওয়ার্ড",
    type: "text",
    maxLength: 250,
    placeholder: "কমা দিয়ে আলাদা করুন — যেমন: সিরাজগঞ্জ ডাক্তার, ডাক্তার সিরাজগঞ্জ, চেম্বার সিরাজগঞ্জ, হাসপাতাল সিরাজগঞ্জ",
  },
];

export default function SEOTab({ values, saveFields, clearFields }) {
  return (
    <SettingsFieldGroup
      title="SEO সেটিংস"
      description="সার্চ ইঞ্জিনে ওয়েবসাইট কীভাবে দেখাবে তা নিয়ন্ত্রণ করুন।"
      fields={FIELDS}
      values={values}
      onSave={saveFields}
      onClearField={(key) => clearFields([key])}
    />
  );
}
