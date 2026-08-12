import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";

/**
 * সব চার্ট কার্ডের জন্য কমন wrapper — টাইটেল, আইকন, লোডিং ও খালি-স্টেট
 * একইভাবে হ্যান্ডেল করে, যাতে প্রতিটা চার্টে আলাদা করে লিখতে না হয়।
 */
export default function ChartCard({
  title,
  icon: Icon,
  description,
  loading,
  isEmpty,
  emptyLabel = "এখনো পর্যাপ্ত তথ্য নেই",
  height = 260,
  className = "",
  children,
}) {
  return (
    <Card className={className}>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          {Icon && <Icon className="h-4 w-4 text-primary" />}
          {title}
        </CardTitle>
        {description && <p className="text-xs text-muted-foreground">{description}</p>}
      </CardHeader>
      <CardContent>
        {loading ? (
          <div style={{ height }} className="flex items-center justify-center">
            <LoadingSpinner label="লোড হচ্ছে..." />
          </div>
        ) : isEmpty ? (
          <div
            style={{ height }}
            className="flex items-center justify-center text-center text-sm text-muted-foreground"
          >
            {emptyLabel}
          </div>
        ) : (
          <div style={{ height }} className="w-full">
            {children}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
