// Decorative only. Two interwoven radial line-grids at ~6% opacity, drifting slowly.
export default function Guilloche() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 -z-10 opacity-[0.06] motion-safe:animate-[spin_120s_linear_infinite]"
      style={{
        backgroundImage:
          "repeating-radial-gradient(circle at 50% 42%, var(--color-ink) 0 1px, transparent 1px 15px)," +
          "repeating-radial-gradient(circle at 32% 64%, var(--color-thread) 0 1px, transparent 1px 19px)",
      }}
    />
  );
}
