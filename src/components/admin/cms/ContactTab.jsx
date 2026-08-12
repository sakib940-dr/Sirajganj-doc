import SettingsFieldGroup from "@/components/admin/cms/SettingsFieldGroup.jsx";
import { validateEmail, validatePhone, validateUrl } from "@/components/admin/cms/validators.js";

const FIELDS = [
  { key: "contact_phone", label: "যোগাযোগ ফোন নম্বর", type: "text", placeholder: "যেমন: 01XXXXXXXXX", validate: validatePhone },
  { key: "contact_whatsapp", label: "হোয়াটসঅ্যাপ নম্বর", type: "text", placeholder: "যেমন: 8801XXXXXXXXX", validate: validatePhone },
  { key: "contact_email", label: "যোগাযোগ ইমেইল", type: "text", placeholder: "info@example.com", validate: validateEmail },
  { key: "footer_address", label: "ঠিকানা", type: "textarea", rows: 2, maxLength: 300 },
  { key: "contact_map_link", label: "গুগল ম্যাপ লিংক", type: "text", placeholder: "https://maps.google.com/...", validate: validateUrl },
];

export default function ContactTab({ values, saveFields, clearFields }) {
  return (
    <SettingsFieldGroup
      title="যোগাযোগের তথ্য"
      description="ফোন, ইমেইল, ঠিকানা ও ম্যাপ লিংক — এগুলো ফুটার ও যোগাযোগ পাতায় প্রদর্শিত হবে।"
      fields={FIELDS}
      values={values}
      onSave={saveFields}
      onClearField={(key) => clearFields([key])}
    />
  );
}
