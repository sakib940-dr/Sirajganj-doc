import { MessageCircle, Facebook, Send, ChevronDown } from "lucide-react";
import { getOrderChannels } from "@/lib/orderChannels";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu.jsx";

const CHANNEL_ICONS = {
  whatsapp: MessageCircle,
  facebook_page: Facebook,
  messenger: Send,
};

/**
 * "অর্ডার করুন" বাটন — উপলব্ধ চ্যানেল (WhatsApp / Facebook Page / Messenger) অনুযায়ী আচরণ পাল্টায়:
 *   - ০টা চ্যানেল  → কিছুই render হয় না
 *   - ১টা চ্যানেল  → সরাসরি লিংক বাটন (আগের WhatsApp-only আচরণের সাথে হুবহু সামঞ্জস্যপূর্ণ)
 *   - ১+ চ্যানেল   → ড্রপডাউন মেনু, প্রতিটা অপশনে ক্লিকে নিজ নিজ চ্যানেল খোলে
 *
 * প্রতিটা চ্যানেল-লিংকে ক্লিক হলে onOrderClick(channelId) কল হয় (অ্যানালিটিক্স ট্র্যাকিংয়ের জন্য)।
 */
export default function OrderNowMenu({ shop, whatsappMessage, onOrderClick }) {
  const channels = getOrderChannels(shop, whatsappMessage);

  if (channels.length === 0) return null;

  if (channels.length === 1) {
    const channel = channels[0];
    const Icon = CHANNEL_ICONS[channel.id] ?? MessageCircle;
    return (
      <a
        href={channel.url}
        target="_blank"
        rel="noreferrer"
        onClick={() => onOrderClick?.(channel.id)}
        className={`inline-flex items-center gap-2 rounded-lg px-6 py-3 text-sm font-semibold text-white shadow-sm transition-opacity hover:opacity-90 ${channel.colorClass}`}
      >
        <Icon className="h-5 w-5" />
        অর্ডার করুন
      </a>
    );
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          className="inline-flex items-center gap-2 rounded-lg bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground shadow-sm transition-opacity hover:opacity-90"
        >
          <MessageCircle className="h-5 w-5" />
          অর্ডার করুন
          <ChevronDown className="h-4 w-4" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        {channels.map((channel) => {
          const Icon = CHANNEL_ICONS[channel.id] ?? MessageCircle;
          return (
            <DropdownMenuItem key={channel.id} asChild>
              <a
                href={channel.url}
                target="_blank"
                rel="noreferrer"
                onClick={() => onOrderClick?.(channel.id)}
                className="flex items-center gap-2.5"
              >
                <span
                  className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-white ${channel.colorClass}`}
                >
                  <Icon className="h-3.5 w-3.5" />
                </span>
                {channel.label}
              </a>
            </DropdownMenuItem>
          );
        })}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
