import { MapPin, Navigation, ChevronDown, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import ProductRow from "@/components/shared/ProductRow.jsx";

export default function LocationDoctorSection({
  location,
  requestLocation,
  selectArea,
  upazilas,
  products,
  loading,
  viewAllTo,
  showDistance = false,
}) {
  const hasCoordinates = Number.isFinite(Number(location.latitude)) && Number.isFinite(Number(location.longitude));
  const title = location.upazila
    ? `${location.upazila} এলাকার ডাক্তার`
    : location.district
      ? `${location.district} জেলার ডাক্তার`
      : hasCoordinates
        ? "আপনার কাছের ডাক্তার"
        : "আপনার এলাকার ডাক্তার";

  return (
    <>
      <section className="container pt-2 pb-3">
        <div className="rounded-2xl border border-primary/10 bg-primary/5 p-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex min-w-0 items-start gap-3">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <MapPin className="h-5 w-5" />
              </span>
              <div className="min-w-0">
                <h3 className="font-bold">আপনার এলাকার ডাক্তার</h3>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  {location.message || "আপনার অবস্থান ব্যবহার করে কাছাকাছি এলাকার ডাক্তার দেখুন।"}
                </p>
              </div>
            </div>

            <Button
              type="button"
              variant="outline"
              size="sm"
              className="shrink-0 gap-2"
              onClick={requestLocation}
              disabled={location.status === "loading"}
            >
              {location.status === "loading" ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Navigation className="h-4 w-4" />
              )}
              {location.status === "loading" ? "খোঁজা হচ্ছে..." : "অবস্থান অনুমতি দিন"}
            </Button>
          </div>

          <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
            <label className="relative">
              <span className="mb-1 block text-xs font-medium text-muted-foreground">জেলা</span>
              <select
                value={location.district || "সিরাজগঞ্জ"}
                onChange={(e) => selectArea(e.target.value, "")}
                className="h-10 w-full appearance-none rounded-lg border border-border bg-background px-3 pr-9 text-sm"
              >
                <option value="সিরাজগঞ্জ">সিরাজগঞ্জ</option>
              </select>
              <ChevronDown className="pointer-events-none absolute right-3 bottom-3 h-4 w-4 text-muted-foreground" />
            </label>

            <label className="relative">
              <span className="mb-1 block text-xs font-medium text-muted-foreground">উপজেলা</span>
              <select
                value={location.upazila}
                onChange={(e) => selectArea("সিরাজগঞ্জ", e.target.value)}
                className="h-10 w-full appearance-none rounded-lg border border-border bg-background px-3 pr-9 text-sm"
              >
                <option value="">সিরাজগঞ্জ জেলার সব উপজেলা</option>
                {upazilas.map((upazila) => (
                  <option key={upazila} value={upazila}>
                    {upazila}
                  </option>
                ))}
              </select>
              <ChevronDown className="pointer-events-none absolute right-3 bottom-3 h-4 w-4 text-muted-foreground" />
            </label>
          </div>
        </div>
      </section>

      {(location.district || location.upazila || hasCoordinates) && (
        <ProductRow
          title={title}
          subtitle={location.upazila ? `${location.upazila} উপজেলায় প্রকাশিত ডাক্তার প্রোফাইল` : location.district ? "আপনার নির্বাচিত জেলার ডাক্তার প্রোফাইল" : "GPS অবস্থান অনুযায়ী কাছের ডাক্তার"}
          icon={MapPin}
          accentClassName="bg-primary/10 text-primary"
          products={products}
          loading={loading}
          emptyIcon={MapPin}
          emptyTitle="এই এলাকায় এখনো কোনো ডাক্তার প্রোফাইল নেই"
          emptyDescription="অন্য উপজেলা বেছে নিয়ে ডাক্তার দেখতে পারেন।"
          viewAllTo={viewAllTo}
          showDistance={showDistance}
        />
      )}
    </>
  );
}
