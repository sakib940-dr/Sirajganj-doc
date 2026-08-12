import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";

const FIELDS = [
  {
    key: "footer_content",
    label: "ফুটার বর্ণনা টেক্সট",
    type: "textarea",
    rows: 4,
    maxLength: 500,
    placeholder: "ফুটারে সাইটের নামের নিচে যে ছোট বর্ণনা দেখাবে",
  },
  {
    key: "footer_copyright",
    label: "কপিরাইট টেক্সট",
    type: "text",
    maxLength: 150,
    placeholder: "খালি রাখলে ডিফল্ট কপিরাইট লাইন দেখাবে",
    help: "উদাহরণ: © ২০২৬ সিরাজগঞ্জ মার্কেটপ্লেস। সর্বস্বত্ব সংরক্ষিত।",
  },
];

export default function FooterTab({ values, saveFields, clearFields }) {
  return (
    <SettingsFieldGroup
      title="ফুটার কনটেন্ট"
      description="ওয়েবসাইটের সবচেয়ে নিচের ফুটার অংশের কনটেন্ট নিয়ন্ত্রণ করুন।"
      fields={FIELDS}
      values={values}
      onSave={saveFields}
      onClearField={(key) => clearFields([key])}
    />
  );
}
