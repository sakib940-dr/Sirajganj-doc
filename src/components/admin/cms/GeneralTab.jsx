import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";

const FIELDS = [
  { key: "site_name", label: "ওয়েবসাইটের নাম", type: "text", required: true, maxLength: 60, placeholder: "যেমন: সিরাজগঞ্জ মার্কেটপ্লেস" },
  { key: "site_motto", label: "মটো / ট্যাগলাইন", type: "text", maxLength: 120, placeholder: "যেমন: আপনার এলাকার সব চেম্বার, এক জায়গায়" },
  { key: "site_logo_url", label: "ওয়েবসাইট লোগো", type: "image", folder: "branding", aspect: "square" },
  { key: "site_favicon_url", label: "ফেভিকন (ব্রাউজার ট্যাব আইকন)", type: "image", folder: "branding", aspect: "square", help: "বর্গাকার ছবি ব্যবহার করুন, আদর্শ সাইজ 512×512px" },
  { key: "show_location_distance", label: "ডাক্তার কার্ডে দূরত্ব দেখাবেন", type: "checkbox", checkboxLabel: "রোগীর অবস্থান অনুযায়ী কিলোমিটার দূরত্ব দেখান", help: "বন্ধ করলে সবার জন্য দূরত্ব/লোকেশন distance লেখা লুকানো থাকবে। জেলা/উপজেলা filter আলাদাভাবে কাজ করবে।" },
];

export default function GeneralTab({ values, saveFields, clearFields }) {
  return (
    <SettingsFieldGroup
      title="সাধারণ তথ্য"
      description="সাইটের নাম, মটো, লোগো ও ফেভিকন এখান থেকে নিয়ন্ত্রণ করুন — এগুলো পুরো ওয়েবসাইট জুড়ে প্রদর্শিত হবে।"
      fields={FIELDS}
      values={values}
      onSave={saveFields}
      onClearField={(key) => clearFields([key])}
    />
  );
}
