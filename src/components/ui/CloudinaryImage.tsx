import { useState, ImgHTMLAttributes, useMemo } from "react";
import { cn } from "@/lib/utils";
import { cldOptimize, cldSrcSet, cldPlaceholder } from "@/lib/cloudinary";

interface Props extends Omit<ImgHTMLAttributes<HTMLImageElement>, "src" | "srcSet"> {
  src: string | null | undefined;
  alt: string;
  /** Hint for delivered width (Cloudinary will scale, never upscale). */
  width?: number;
  height?: number;
  /** Tailwind aspect ratio container class — keeps space to prevent CLS. */
  aspect?: string;
  rounded?: string;
  /** Responsive sizes attribute. Defaults to mobile-first full width. */
  sizes?: string;
  /** Crop fill (square thumbs) vs limit (natural ratio). */
  fill?: boolean;
  fallback?: React.ReactNode;
}

/**
 * Smart image that:
 * - Rewrites Cloudinary URLs with f_auto, q_auto and responsive widths
 * - Lazy loads, shows blurred LQIP placeholder
 * - Falls back gracefully for non-Cloudinary or missing URLs
 */
export function CloudinaryImage({
  src,
  alt,
  width = 800,
  height,
  aspect,
  rounded,
  sizes = "(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw",
  fill = false,
  fallback,
  className,
  ...rest
}: Props) {
  const [loaded, setLoaded] = useState(false);
  const [errored, setErrored] = useState(false);

  const optimized = useMemo(
    () =>
      cldOptimize(src, {
        width,
        height,
        crop: fill ? "fill" : "limit",
        gravity: fill ? "auto" : undefined,
      }),
    [src, width, height, fill]
  );
  const srcSet = useMemo(() => (src ? cldSrcSet(src) : ""), [src]);
  const placeholder = useMemo(() => (src ? cldPlaceholder(src) : ""), [src]);

  if (!src || errored) {
    return (
      <div
        className={cn(
          "flex items-center justify-center bg-muted text-muted-foreground",
          aspect,
          rounded,
          className
        )}
      >
        {fallback ?? <span className="text-xs">No image</span>}
      </div>
    );
  }

  return (
    <div
      className={cn("relative overflow-hidden bg-muted/40", aspect, rounded, className)}
      style={placeholder ? { backgroundImage: `url(${placeholder})`, backgroundSize: "cover", backgroundPosition: "center" } : undefined}
    >
      <img
        {...rest}
        src={optimized}
        srcSet={srcSet || undefined}
        sizes={sizes}
        alt={alt}
        loading={rest.loading ?? "lazy"}
        decoding="async"
        onLoad={() => setLoaded(true)}
        onError={() => setErrored(true)}
        className={cn(
          "h-full w-full object-cover transition-opacity duration-500",
          loaded ? "opacity-100" : "opacity-0"
        )}
      />
    </div>
  );
}

export default CloudinaryImage;
