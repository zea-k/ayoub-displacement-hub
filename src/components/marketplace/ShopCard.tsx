import { Link } from "react-router-dom";
import { motion, useMotionValue, useTransform, useSpring } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { Sparkles, Heart } from "lucide-react";
import { Badge } from "@/components/ui/badge";

export interface MarketplaceShop {
  owner_id: string;
  business_name: string;
  slug: string;
  logo_url: string | null;
  description: string | null;
  category: string | null;
  category_id: string | null;
  category_name?: string;
  theme_color: string;
  is_featured?: boolean;
  is_open?: boolean; // optional online status
  follower_count?: number | null;
  engagement_score?: number | null;
  latitude?: number | null;
  longitude?: number | null;
}

interface ShopCardProps {
  shop: MarketplaceShop;
  featured?: boolean;
  onClick?: () => void;
  /**
   * Horizontal mode = uniform fixed-size card used in horizontal scrolls.
   * Grid mode = same card but full-width inside its grid cell.
   */
  variant?: "horizontal" | "grid";
}

export default function ShopCard({ shop, featured, onClick, variant = "grid" }: ShopCardProps) {
  const accentColor = shop.theme_color || "#7c3aed";
  const avatarBg = `${accentColor}1a`;

  const ref = useRef<HTMLDivElement>(null);
  const [favorite, setFavorite] = useState(false);

  // Parallax: logo translates slightly on hover/tap
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  const tx = useTransform(useSpring(mx, { stiffness: 200, damping: 20 }), (v) => v * 6);
  const ty = useTransform(useSpring(my, { stiffness: 200, damping: 20 }), (v) => v * 6);

  const onMove = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect) return;
    mx.set(((e.clientX - rect.left) / rect.width - 0.5) * 2);
    my.set(((e.clientY - rect.top) / rect.height - 0.5) * 2);
  };
  const onLeave = () => {
    mx.set(0);
    my.set(0);
  };

  const sizing =
    variant === "horizontal"
      ? "w-[150px] h-[200px] sm:w-[170px] sm:h-[220px]"
      : "w-full h-[200px] sm:h-[220px]";

  return (
    <motion.div
      ref={ref}
      onMouseMove={onMove}
      onMouseLeave={onLeave}
      whileHover={{ y: -4, scale: 1.03 }}
      whileTap={{ scale: 0.97 }}
      transition={{ type: "spring", stiffness: 300, damping: 22 }}
      className={`${sizing} relative shrink-0`}
    >
      <Link
        to={`/market/shop/${shop.slug}`}
        onClick={onClick}
        className="apple-card group relative block h-full w-full !rounded-[22px]"
      >
        {/* Soft gradient wash using shop accent */}
        <div
          className="pointer-events-none absolute inset-0 opacity-70"
          style={{
            background: `radial-gradient(circle at 50% 0%, ${accentColor}28 0%, transparent 65%)`,
          }}
        />

        {/* Featured ribbon */}
        {(featured || shop.is_featured) && (
          <div className="absolute top-2.5 left-2.5 z-10 inline-flex items-center gap-1 rounded-full bg-amber-400/90 text-black text-[10px] font-bold px-2 py-0.5 shadow-md">
            <Sparkles className="h-3 w-3" /> Featured
          </div>
        )}

        {/* Favorite button */}
        <button
          type="button"
          onClick={(e) => {
            e.preventDefault();
            setFavorite((v) => !v);
          }}
          className="absolute top-2 right-2 z-10 h-7 w-7 rounded-full bg-white/80 backdrop-blur-sm border border-gray-200 flex items-center justify-center hover:bg-white transition-colors shadow-sm"
          aria-label="Save shop"
        >
          <Heart
            className={`h-3.5 w-3.5 transition-colors ${
              favorite ? "fill-rose-500 text-rose-500" : "text-gray-500"
            }`}
          />
        </button>

        {/* Open status dot */}
        {typeof shop.is_open === "boolean" && (
          <div className="absolute bottom-[68px] right-3 z-10 flex items-center gap-1 text-[10px] font-medium">
            <span
              className={`h-1.5 w-1.5 rounded-full ${
                shop.is_open ? "bg-emerald-400 shadow-[0_0_6px_rgba(52,211,153,0.8)]" : "bg-rose-400"
              }`}
            />
            <span className={shop.is_open ? "text-emerald-300" : "text-rose-300"}>
              {shop.is_open ? "Open" : "Closed"}
            </span>
          </div>
        )}

        {/* Logo block (centered top, with parallax) */}
        <div className="relative flex items-center justify-center pt-7 pb-3">
          <motion.div
            style={{ x: tx, y: ty }}
            className="h-[68px] w-[68px] sm:h-[76px] sm:w-[76px] rounded-2xl flex items-center justify-center overflow-hidden ring-1 ring-gray-200 shadow-md"
          >
            <div
              className="h-full w-full flex items-center justify-center text-white font-bold text-2xl"
              style={{ backgroundColor: avatarBg }}
            >
              {shop.logo_url ? (
                <CloudinaryImage
                  src={shop.logo_url}
                  alt={shop.business_name}
                  width={160}
                  fill
                  aspect="h-full w-full"
                  sizes="80px"
                />
              ) : (
                <span style={{ color: accentColor }}>
                  {shop.business_name.charAt(0).toUpperCase()}
                </span>
              )}
            </div>
          </motion.div>
        </div>

        {/* Bottom info */}
        <div className="absolute bottom-0 left-0 right-0 p-3 pt-2">
          <h3 className="text-sm font-semibold text-foreground text-center truncate">
            {shop.business_name}
          </h3>
          {(shop.category_name || shop.category) && (
            <div className="mt-1.5 flex justify-center">
              <Badge
                variant="outline"
                className="text-[10px] border-border bg-background/70 text-muted-foreground px-2 py-0 rounded-full font-normal backdrop-blur"
              >
                {shop.category_name || shop.category}
              </Badge>
            </div>
          )}
        </div>
      </Link>
    </motion.div>
  );
}

/**
 * Skeleton placeholder matching ShopCard dimensions
 */
export function ShopCardSkeleton({ variant = "grid" }: { variant?: "horizontal" | "grid" }) {
  const sizing =
    variant === "horizontal"
      ? "w-[150px] h-[200px] sm:w-[170px] sm:h-[220px]"
      : "w-full h-[200px] sm:h-[220px]";
  return (
    <div className={`${sizing} rounded-[22px] bg-gray-100 border border-gray-200 animate-pulse shrink-0`} />
  );
}
