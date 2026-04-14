import type { TimeSource, SyncStatus } from "@/hooks/useTimeSync";

interface StatusBarProps {
  timeSource: TimeSource;
  syncStatus: SyncStatus;
  gaFramTidEnabled: boolean;
  gaFramTidOffset: number;
  visible: boolean;
}

const syncLabels: Record<SyncStatus, string> = {
  acquiring: "Acquiring…",
  synced: "Synced",
  "drift-warning": "Drift Warning",
  unavailable: "No GNSS",
};

const StatusBar = ({ timeSource, syncStatus, gaFramTidEnabled, gaFramTidOffset, visible }: StatusBarProps) => {
  if (!visible) return null;

  return (
    <div className="flex w-full items-center justify-between px-4 py-3">
      <div className="flex items-center gap-3">
        <span className="status-text text-muted-foreground">
          {timeSource === "gnss" ? "GNSS" : "DEVICE"}
        </span>
        <span
          className={`status-text ${
            syncStatus === "synced"
              ? "text-primary"
              : syncStatus === "drift-warning"
              ? "text-destructive"
              : "text-muted-foreground"
          }`}
        >
          {syncLabels[syncStatus]}
        </span>
      </div>
      {gaFramTidEnabled && (
        <span className="status-text text-primary">
          +{gaFramTidOffset} MIN
        </span>
      )}
    </div>
  );
};

export default StatusBar;
