import { MapPin, ExternalLink } from "lucide-react"
import { Button } from "@/components/ui/button"
import type { BengkelMapPreviewProps } from "@/components/features/bengkels/types/bengkel"

function buildEmbedUrl(latitude: number, longitude: number): string {
  const delta = 0.01
  const bbox = [
    longitude - delta,
    latitude - delta,
    longitude + delta,
    latitude + delta,
  ].join(",")
  return `https://www.openstreetmap.org/export/embed.html?bbox=${encodeURIComponent(
    bbox
  )}&layer=mapnik&marker=${latitude},${longitude}`
}

function buildMapsUrl(
  address: string,
  latitude: number | null,
  longitude: number | null
): string {
  const query =
    latitude !== null && longitude !== null
      ? `${latitude},${longitude}`
      : address
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
    query
  )}`
}

export function BengkelMapPreview({
  name,
  address,
  latitude,
  longitude,
}: BengkelMapPreviewProps) {
  const hasCoordinates = latitude !== null && longitude !== null
  const mapsUrl = buildMapsUrl(address, latitude, longitude)

  return (
    <div className="flex flex-col gap-2">
      {hasCoordinates ? (
        <iframe
          title={`Peta lokasi ${name}`}
          src={buildEmbedUrl(latitude, longitude)}
          className="h-48 w-full rounded-lg border"
          loading="lazy"
        />
      ) : (
        <div className="flex h-24 w-full items-center justify-center rounded-lg border border-dashed text-sm text-muted-foreground">
          <MapPin className="mr-2 size-4" />
          Koordinat tidak tersedia
        </div>
      )}
      <Button
        variant="outline"
        size="sm"
        nativeButton={false}
        render={<a href={mapsUrl} target="_blank" rel="noreferrer" />}
      >
        <ExternalLink />
        Buka di Google Maps
      </Button>
    </div>
  )
}
