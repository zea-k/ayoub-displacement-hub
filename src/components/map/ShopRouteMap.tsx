import { useEffect, useMemo, lazy, Suspense } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { MapPin, Navigation, Clock, Route as RouteIcon, Loader2, AlertCircle } from "lucide-react";
import { useShopRoute, useUserLocation } from "@/hooks/useShopRoute";

// Lazy-load the leaflet pieces so the bundle stays small until needed.
const MapInner = lazy(() => import("./ShopRouteMapInner"));

interface Props {
  shopName: string;
  latitude: number | null | undefined;
  longitude: number | null | undefined;
}

function formatDistance(meters: number) {
  if (meters < 1000) return `${Math.round(meters)} m`;
  return `${(meters / 1000).toFixed(1)} km`;
}
function formatDuration(seconds: number) {
  const m = Math.round(seconds / 60);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
}

export default function ShopRouteMap({ shopName, latitude, longitude }: Props) {
  const shopPos = useMemo<[number, number] | null>(
    () => (latitude != null && longitude != null ? [latitude, longitude] : null),
    [latitude, longitude],
  );
  const { position: userPos, denied, loading: locLoading, request } = useUserLocation();

  useEffect(() => {
    // Auto-request once on mount.
    request();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const { route, loading: routeLoading, error: routeError } = useShopRoute(userPos, shopPos);

  if (!shopPos) {
    return (
      <Card className="p-6 text-center border-border/60 bg-card/60 backdrop-blur">
        <MapPin className="h-8 w-8 mx-auto text-muted-foreground opacity-60" />
        <p className="mt-2 text-sm text-muted-foreground">
          Mmiliki wa duka hajaweka eneo la duka bado.
        </p>
      </Card>
    );
  }

  const directionsUrl = userPos
    ? `https://www.openstreetmap.org/directions?from=${userPos[0]},${userPos[1]}&to=${shopPos[0]},${shopPos[1]}`
    : `https://www.openstreetmap.org/?mlat=${shopPos[0]}&mlon=${shopPos[1]}#map=16/${shopPos[0]}/${shopPos[1]}`;

  return (
    <Card className="overflow-hidden border border-border/60 bg-card/70 backdrop-blur shadow-lg">
      <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 border-b border-border/60 bg-gradient-to-r from-primary/5 to-accent/5">
        <div className="flex items-center gap-2">
          <div className="p-1.5 rounded-lg bg-primary/10 border border-primary/20">
            <MapPin className="h-4 w-4 text-primary" />
          </div>
          <div>
            <p className="text-sm font-semibold leading-tight">Find this shop</p>
            <p className="text-[11px] text-muted-foreground">Route from your location to {shopName}</p>
          </div>
        </div>
        <Button asChild size="sm" variant="outline" className="h-8">
          <a href={directionsUrl} target="_blank" rel="noopener noreferrer">
            <Navigation className="mr-1.5 h-3.5 w-3.5" /> Open in Maps
          </a>
        </Button>
      </div>

      <div className="relative h-[360px] w-full bg-muted/30">
        <Suspense
          fallback={
            <div className="absolute inset-0 flex items-center justify-center">
              <Loader2 className="h-6 w-6 animate-spin text-primary" />
            </div>
          }
        >
          <MapInner shopPos={shopPos} userPos={userPos} routeCoords={route?.coords ?? null} shopName={shopName} />
        </Suspense>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-2 p-3 bg-background/60">
        <Stat
          icon={<RouteIcon className="h-4 w-4" />}
          label="Distance"
          value={route ? formatDistance(route.distance_m) : routeLoading ? "…" : "—"}
        />
        <Stat
          icon={<Clock className="h-4 w-4" />}
          label="Travel time"
          value={route ? formatDuration(route.duration_s) : routeLoading ? "…" : "—"}
        />
        <div className="col-span-2 md:col-span-1 flex items-center">
          {denied ? (
            <Button size="sm" variant="ghost" onClick={request} className="w-full h-9 text-xs">
              <AlertCircle className="mr-1.5 h-3.5 w-3.5" /> Enable location for route
            </Button>
          ) : !userPos && locLoading ? (
            <span className="flex items-center justify-center w-full text-xs text-muted-foreground">
              <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" /> Locating you…
            </span>
          ) : routeError ? (
            <span className="text-[11px] text-destructive truncate" title={routeError}>
              Route error
            </span>
          ) : (
            <span className="text-[11px] text-muted-foreground">Live route powered by OSRM</span>
          )}
        </div>
      </div>
    </Card>
  );
}

function Stat({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="rounded-lg border border-border/50 bg-card/60 px-3 py-2 flex items-center gap-2">
      <span className="text-primary">{icon}</span>
      <div>
        <p className="text-[10px] uppercase tracking-wide text-muted-foreground">{label}</p>
        <p className="text-sm font-semibold leading-tight">{value}</p>
      </div>
    </div>
  );
}
