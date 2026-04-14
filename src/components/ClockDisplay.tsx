import type { SyncedTime } from "@/hooks/useTimeSync";

interface ClockDisplayProps {
  time: SyncedTime;
  isGoSecond: boolean;
}

const pad = (n: number) => n.toString().padStart(2, "0");

const ClockDisplay = ({ time, isGoSecond }: ClockDisplayProps) => {
  return (
    <div className="flex flex-1 items-center justify-center px-4">
      <div
        className={`clock-text clock-glow transition-colors duration-200 ${
          isGoSecond ? "text-primary" : "text-foreground"
        }`}
        style={{
          fontSize: "clamp(3rem, 18vw, 12rem)",
          lineHeight: 1,
        }}
      >
        {pad(time.hours)}:{pad(time.minutes)}:{pad(time.seconds)}
      </div>
    </div>
  );
};

export default ClockDisplay;
