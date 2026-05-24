import { cn } from "@/lib/utils";
import type { HTMLAttributes, ReactNode } from "react";

interface PremiumFrameProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  /** Inner container className (background, padding, etc.) */
  innerClassName?: string;
}

/**
 * Shared premium gradient frame used across the entire app
 * (marketing, marketplace, dashboard, public store).
 *
 * Visuals: conic gradient border, soft dual-color shadow, rounded corners,
 * thin inner ring. Keep this as the single source of truth so the look
 * stays identical everywhere.
 */
export function PremiumFrame({
  children,
  className,
  innerClassName,
  ...rest
}: PremiumFrameProps) {
  return (
    <div
      {...rest}
      className={cn(
        "relative rounded-[1.75rem] p-[1.5px] bg-[conic-gradient(from_140deg_at_50%_50%,hsl(var(--primary)/0.55),hsl(var(--accent)/0.45),hsl(var(--primary)/0.15),hsl(var(--accent)/0.5),hsl(var(--primary)/0.55))] shadow-[0_30px_80px_-30px_hsl(var(--primary)/0.45),0_10px_40px_-20px_hsl(var(--accent)/0.35)]",
        className,
      )}
    >
      <div
        className={cn(
          "relative overflow-hidden rounded-[1.65rem] ring-1 ring-white/10",
          innerClassName,
        )}
      >
        {children}
      </div>
    </div>
  );
}

export default PremiumFrame;
