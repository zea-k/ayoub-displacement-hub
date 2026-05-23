import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { useTranslation } from "react-i18next";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import SignUpButton from "@/components/marketing/SignUpButton";

gsap.registerPlugin(ScrollTrigger);

const slideKeys = [
  {
    key: "stopLosing",
    bg: "from-primary/10 via-accent/5 to-transparent",
  },
  {
    key: "trackSales",
    bg: "from-emerald-500/10 via-teal-500/5 to-transparent",
  },
  {
    key: "controlStock",
    bg: "from-primary/10 via-primary/5 to-transparent",
  },
  {
    key: "manageExpenses",
    bg: "from-accent/10 via-orange-500/5 to-transparent",
  },
  {
    key: "sellOnline",
    bg: "from-rose-500/10 via-pink-500/5 to-transparent",
  },
  {
    key: "knowProfit",
    bg: "from-cyan-500/10 via-blue-500/5 to-transparent",
  },
  {
    key: "takeControl",
    bg: "from-primary/15 via-accent/10 to-transparent",
  },
] as const;

export default function MarketingHomePage() {
  const { t } = useTranslation();

  const slides = slideKeys.map((s) => ({
    title: t(`marketing.slides.${s.key}`),
    bg: s.bg,
  }));

  const containerRef = useRef<HTMLDivElement>(null);
  const slideRefs = useRef<HTMLElement[]>([]);
  const [activeSlide, setActiveSlide] = useState(0);

  useEffect(() => {
    const container = containerRef.current;

    if (!container) return;

    const tl = gsap.timeline({
      defaults: { ease: "none", force3D: true },
      scrollTrigger: {
        trigger: container,
        start: "top top",
        end: `+=${slides.length * 100}%`,
        scrub: 0.6,
        pin: true,
        pinSpacing: true,
        anticipatePin: 1,
        invalidateOnRefresh: true,
        onUpdate: (self) => {
          const nextIndex = Math.min(
            slides.length - 1,
            Math.round(self.progress * (slides.length - 1))
          );

          setActiveSlide((prev) =>
            prev === nextIndex ? prev : nextIndex
          );
        },
      },
    });

    slides.forEach((_, index) => {
      const current = slideRefs.current[index];

      if (!current) return;

      gsap.set(current, {
        autoAlpha: index === 0 ? 1 : 0,
        scale: index === 0 ? 1 : 1.04,
        zIndex: index === 0 ? 5 : 1,
        willChange: "transform, opacity",
        force3D: true,
      });

      if (index > 0) {
        const previous = slideRefs.current[index - 1];

        tl.to(
          previous,
          {
            autoAlpha: 0,
            scale: 0.97,
            duration: 1,
          },
          `slide${index}`
        )
          .set(previous, { zIndex: 1 }, `slide${index}+=0.1`)
          .set(current, { zIndex: 5 }, `slide${index}`)
          .fromTo(
            current,
            {
              autoAlpha: 0,
              scale: 1.04,
              y: 20,
            },
            {
              autoAlpha: 1,
              scale: 1,
              y: 0,
              duration: 1,
            },
            `slide${index}`
          );
      }
    });

    return () => {
      ScrollTrigger.getAll().forEach((trigger) => trigger.kill());
      tl.kill();
    };
  }, [slides.length]);

  return (
    <main className="min-h-screen overflow-hidden bg-gradient-to-br from-background via-background/95 to-background/90 text-foreground">
      <div ref={containerRef} className="relative h-screen">
        {/* Background */}
        <div className="absolute inset-0 bg-gradient-to-br from-background via-background/95 to-background/90 backdrop-blur-3xl" />

        <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(120,119,198,0.1),transparent_50%)]" />

        <div className="absolute inset-0 bg-[radial-gradient(circle_at_70%_80%,rgba(255,107,107,0.1),transparent_50%)]" />

        {slides.map((slide, index) => (
          <section
            key={slide.title}
            ref={(el) => {
              if (el) slideRefs.current[index] = el;
            }}
            className="absolute inset-0 flex items-center justify-center px-4 py-12"
          >
            <div className="relative w-full max-w-5xl text-center">
              {/* Badge */}
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6 }}
                className="mb-6 inline-flex items-center gap-2 rounded-full border border-primary/20 bg-gradient-to-r from-primary/10 via-accent/5 to-primary/10 px-4 py-2 text-sm font-semibold text-primary backdrop-blur-sm"
              >
                <div className="h-2 w-2 animate-pulse rounded-full bg-gradient-to-r from-primary to-accent" />

                <span>ZEETOP Business Management</span>
              </motion.div>

              {/* Heading */}
              <motion.h1
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.2 }}
                className="bg-gradient-to-r from-foreground via-foreground to-foreground/80 bg-clip-text text-4xl font-bold leading-tight tracking-tight text-transparent md:text-5xl lg:text-6xl"
              >
                {slide.title}
              </motion.h1>

              {/* Demo Card */}
              <motion.div
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.4 }}
                className="mt-12 flex justify-center"
              >
                <div className="relative h-52 w-full max-w-3xl rounded-[2.5rem] p-[1px] overflow-hidden">
                  {/* Rotating half border */}
                  <motion.div
                    aria-hidden
                    className="absolute inset-[-50%] rounded-full"
                    style={{
                      background:
                        "conic-gradient(from 0deg, transparent 0deg, transparent 180deg, hsl(var(--primary)) 240deg, hsl(var(--accent)) 320deg, transparent 360deg)",
                    }}
                    animate={{ rotate: 360 }}
                    transition={{ duration: 8, repeat: Infinity, ease: "linear" }}
                  />
                  <div className="relative h-full w-full flex items-center justify-center rounded-[2.5rem] bg-gradient-to-br from-card/80 via-card/60 to-card/40 backdrop-blur-xl shadow-inner shadow-black/10">
                    <div className="text-center px-6">
                      <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-primary/20 to-accent/20">
                        <div className="h-8 w-8 rounded-xl bg-gradient-to-br from-primary to-accent" />
                      </div>
                      <p className="text-xl md:text-2xl font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
                        Own the Market
                      </p>
                    </div>
                  </div>
                </div>
              </motion.div>

              {/* CTA */}
              <motion.div
                initial={{ opacity: 0, y: 50 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.8, delay: 0.6 }}
                className="mt-12 flex flex-col items-center gap-4 sm:flex-row sm:justify-center"
              >
                <motion.div
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                >
                  <SignUpButton className="rounded-2xl bg-gradient-to-r from-primary via-primary to-accent px-10 py-4 font-semibold text-white shadow-2xl shadow-primary/30 transition-all duration-300 hover:from-primary/90 hover:via-primary/95 hover:to-accent/90 hover:shadow-primary/40">
                    {t("marketing.cta.startFree")}
                  </SignUpButton>
                </motion.div>

                <Link
                  to="/market"
                  className="inline-flex items-center justify-center rounded-2xl border border-border/50 bg-card/80 px-10 py-4 text-sm font-semibold text-foreground shadow-lg backdrop-blur-sm transition-all duration-300 hover:bg-card hover:text-primary hover:shadow-xl"
                >
                  {t("marketing.cta.browseMarket")}
                </Link>
              </motion.div>
            </div>
          </section>
        ))}

        {/* Right Navigation Dots */}
        <div className="absolute right-6 top-1/2 hidden -translate-y-1/2 flex-col items-center gap-3 lg:flex">
          {slides.map((_, index) => (
            <motion.div
              key={index}
              initial={{ scale: 0.8, opacity: 0.5 }}
              animate={{
                scale: activeSlide === index ? 1.2 : 0.8,
                opacity: activeSlide === index ? 1 : 0.5,
              }}
              transition={{ duration: 0.3 }}
              className="flex items-center gap-3"
            >
              <div
                className={`h-3 w-3 rounded-full transition-all duration-300 ${
                  activeSlide === index
                    ? "bg-gradient-to-r from-primary to-accent shadow-[0_0_20px_rgba(120,119,198,0.6)]"
                    : "bg-border/60 hover:bg-border/80"
                }`}
              />
            </motion.div>
          ))}
        </div>
      </div>
    </main>
  );
}