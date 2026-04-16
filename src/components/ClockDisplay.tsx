import type { SyncedTime } from "@/hooks/useTimeSync";
import { CLOCK_FONTS, type ClockFont } from "@/hooks/useSettings";

interface ClockDisplayProps {
  time: SyncedTime;
  isGoSecond: boolean;
  gaFramTidEnabled: boolean;
  clockFont: ClockFont;
  clockBold: boolean;
}

const pad = (n: number) => n.toString().padStart(2, "0");

const ClockDisplay = ({ time, isGoSecond, gaFramTidEnabled, clockFont, clockBold }: ClockDisplayProps) => {
  const fontFamily = CLOCK_FONTS[clockFont].family;
  const fontWeight = clockBold ? 700 : 400;

  return (
    <div className="flex flex-1 flex-col items-center justify-center px-2">
      {gaFramTidEnabled && (
        <div
          className="status-text text-primary mb-1"
          style={{ fontFamily, fontWeight }}
        >
          Gå-fram-tid
        </div>
      )}
      <div
        className={`clock-text clock-glow transition-colors duration-200 ${
          isGoSecond ? "text-primary" : "text-foreground"
        }`}
        style={{
          fontSize: "clamp(3rem, 20vw, 16rem)",
          lineHeight: 1,
          fontFamily,
          fontWeight,
        }}
      >
        {pad(time.hours)}:{pad(time.minutes)}:{pad(time.seconds)}
      </div>
    </div>
  );
};

export default ClockDisplay;
