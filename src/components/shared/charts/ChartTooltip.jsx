// সব চার্টে ব্যবহৃত কমন থিমড টুলটিপ — অ্যাপের কার্ড স্টাইলের সাথে সামঞ্জস্যপূর্ণ
export function ChartTooltip({ active, payload, label, valueLabel }) {
  if (!active || !payload || payload.length === 0) return null;

  return (
    <div className="rounded-lg border border-border bg-card px-3 py-2 text-xs shadow-md">
      {label && <p className="mb-1 font-medium text-foreground">{label}</p>}
      <div className="space-y-0.5">
        {payload.map((entry, idx) => (
          <div key={idx} className="flex items-center gap-2">
            <span
              className="h-2 w-2 shrink-0 rounded-full"
              style={{ backgroundColor: entry.color || entry.fill }}
            />
            <span className="text-muted-foreground">{entry.name}:</span>
            <span className="font-semibold tabular-nums text-foreground">
              {entry.value?.toLocaleString?.() ?? entry.value}
              {valueLabel ? ` ${valueLabel}` : ""}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
