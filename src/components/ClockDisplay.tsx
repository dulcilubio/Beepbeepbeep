import type { SyncedTime } from "@/hooks/useTimeSync";
import { CLOCK_FONTS, type ClockFont } from "@/hooks/useSettings";

interface ClockDisplayProps {
  time: SyncedTime;
  isGoSecond: boolean;
  gaFramTidEnabled: boolean;
  clockFont: ClockFont;
}

const pad = (n: number) => n.toString().padStart(2, "0");

const ClockDisplay = ({ time, isGoSecond, gaFramTidEnabled, gaFramTidOffset, clockFont }: ClockDisplayProps) => {
  const fontFamily = CLOCK_FONTS[clockFont].family;

  return (
    <div className="flex flex-1 flex-col items-center justify-center px-4">
      {gaFramTidEnabled && (
        <div
          className="status-text text-primary mb-2"
          style={{ fontFamily }}
        >
          Gå-fram-tid +{gaFramTidOffset} min
        </div>
      )}
      <div
        className={`clock-text clock-glow transition-colors duration-200 ${
          isGoSecond ? "text-primary" : "text-foreground"
        }`}
        style={{
          fontSize: "clamp(3rem, 18vw, 12rem)",
          lineHeight: 1,
          fontFamily,
        }}
      >
        {pad(time.hours)}:{pad(time.minutes)}:{pad(time.seconds)}
      </div>
    </div>
  );
};

export default ClockDisplay;
