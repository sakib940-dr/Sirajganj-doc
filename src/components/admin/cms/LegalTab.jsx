import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";

const PRIVACY_FIELDS = [
  {
    key: "privacy_policy_content",
    label: "Privacy Policy কনটেন্ট",
    type: "textarea",
    rows: 14,
    maxLength: 10000,
    placeholder: "আপনার প্রাইভেসি পলিসি এখানে লিখুন...",
  },
];

const TERMS_FIELDS = [
  {
    key: "terms_conditions_content",
    label: "Terms & Conditions কনটেন্ট",
    type: "textarea",
    rows: 14,
    maxLength: 10000,
    placeholder: "আপনার শর্তাবলী এখানে লিখুন...",
  },
];

export default function LegalTab({ values, saveFields, clearFields }) {
  return (
    <div className="space-y-6">
      <SettingsFieldGroup
        title="Privacy Policy"
        description="ব্যবহারকারীদের তথ্য কীভাবে সংগ্রহ ও ব্যবহার করা হয় তা এখানে লিখুন।"
        fields={PRIVACY_FIELDS}
        values={values}
        onSave={saveFields}
        onClearField={(key) => clearFields([key])}
      />
      <SettingsFieldGroup
        title="Terms & Conditions"
        description="ওয়েবসাইট ব্যবহারের শর্তাবলী এখানে লিখুন।"
        fields={TERMS_FIELDS}
        values={values}
        onSave={saveFields}
        onClearField={(key) => clearFields([key])}
      />
    </div>
  );
}
