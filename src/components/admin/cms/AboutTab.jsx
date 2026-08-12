import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";

const FIELDS = [
  {
    key: "about_us_content",
    label: "About Us কনটেন্ট",
    type: "textarea",
    rows: 12,
    maxLength: 5000,
    placeholder: "আপনার প্ল্যাটফর্ম সম্পর্কে বিস্তারিত লিখুন...",
    help: "প্রতিটি নতুন লাইন আলাদা প্যারাগ্রাফ হিসেবে প্রদর্শিত হবে।",
  },
];

export default function AboutTab({ values, saveFields, clearFields }) {
  return (
    <SettingsFieldGroup
      title="About Us"
      description="ওয়েবসাইটের 'আমাদের সম্পর্কে' পাতার কনটেন্ট নিয়ন্ত্রণ করুন।"
      fields={FIELDS}
      values={values}
      onSave={saveFields}
      onClearField={(key) => clearFields([key])}
    />
  );
}
