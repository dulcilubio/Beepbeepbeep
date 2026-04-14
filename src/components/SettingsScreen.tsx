import {
  Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription,
} from "@/components/ui/sheet";
import { Switch } from "@/components/ui/switch";
import { Slider } from "@/components/ui/slider";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { CLOCK_FONTS, type Settings, type ClockFont } from "@/hooks/useSettings";
import type { TimeSource, SyncStatus } from "@/hooks/useTimeSync";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

interface SettingsScreenProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  settings: Settings;
  onUpdate: (patch: Partial<Settings>) => void;
  timeSource: TimeSource;
  syncStatus: SyncStatus;
}

const syncLabels: Record<SyncStatus, string> = {
  acquiring: "Acquiring…",
  synced: "Synced",
  "drift-warning": "Drift Warning",
  unavailable: "Unavailable",
};

const SettingsScreen = ({ open, onOpenChange, settings, onUpdate, timeSource, syncStatus }: SettingsScreenProps) => {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="max-h-[85vh] overflow-y-auto rounded-t-2xl">
        <SheetHeader className="pb-4">
          <SheetTitle className="clock-text text-foreground">Settings</SheetTitle>
          <SheetDescription className="sr-only">Configure startclock settings</SheetDescription>
        </SheetHeader>

        <div className="space-y-6 pb-8">
          {/* Time Source */}
          <section>
            <h3 className="status-text text-muted-foreground mb-3">Time Source</h3>
            <div className="flex items-center justify-between">
              <span className="text-sm text-foreground">
                {timeSource === "gnss" ? "GNSS" : "Device Clock"}
              </span>
              <span className={`status-text ${syncStatus === "synced" ? "text-primary" : "text-muted-foreground"}`}>
                {syncLabels[syncStatus]}
              </span>
            </div>
          </section>

          <Separator />

          {/* Start Interval */}
          <section>
            <h3 className="status-text text-muted-foreground mb-3">Start Interval</h3>
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label className="text-sm text-foreground">Interval</Label>
                <span className="text-sm text-primary font-mono">{settings.startInterval}s</span>
              </div>
              <Slider
                min={10}
                max={60}
                step={10}
                value={[settings.startInterval]}
                onValueChange={([v]) => onUpdate({ startInterval: v })}
              />
            </div>
          </section>

          <Separator />

          {/* Gå-fram-tid */}
          <section>
            <h3 className="status-text text-muted-foreground mb-3">Gå-fram-tid</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <Label htmlFor="gft-toggle" className="text-sm text-foreground">Enabled</Label>
                <Switch
                  id="gft-toggle"
                  checked={settings.gaFramTidEnabled}
                  onCheckedChange={(v) => onUpdate({ gaFramTidEnabled: v })}
                />
              </div>
              {settings.gaFramTidEnabled && (
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <Label className="text-sm text-foreground">Offset</Label>
                    <span className="text-sm text-primary font-mono">{settings.gaFramTidOffset} min</span>
                  </div>
                  <Slider
                    min={0}
                    max={5}
                    step={1}
                    value={[settings.gaFramTidOffset]}
                    onValueChange={([v]) => onUpdate({ gaFramTidOffset: v })}
                  />
                </div>
              )}
            </div>
          </section>

          <Separator />

          {/* Audio */}
          <section>
            <h3 className="status-text text-muted-foreground mb-3">Audio</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <Label htmlFor="beep-toggle" className="text-sm text-foreground">Beeps</Label>
                <Switch
                  id="beep-toggle"
                  checked={settings.beepsEnabled}
                  onCheckedChange={(v) => onUpdate({ beepsEnabled: v })}
                />
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label className="text-sm text-muted-foreground">Countdown Hz</Label>
                  <span className="text-sm font-mono text-foreground">{settings.countdownBeepHz}</span>
                </div>
                <Slider
                  min={200}
                  max={2000}
                  step={10}
                  value={[settings.countdownBeepHz]}
                  onValueChange={([v]) => onUpdate({ countdownBeepHz: v })}
                />
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label className="text-sm text-muted-foreground">Countdown length</Label>
                  <span className="text-sm font-mono text-foreground">{(settings.countdownBeepMs / 1000).toFixed(2)}s</span>
                </div>
                <Slider
                  min={10}
                  max={990}
                  step={10}
                  value={[settings.countdownBeepMs]}
                  onValueChange={([v]) => onUpdate({ countdownBeepMs: v })}
                />
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label className="text-sm text-muted-foreground">Go-beep Hz</Label>
                  <span className="text-sm font-mono text-foreground">{settings.goBeepHz}</span>
                </div>
                <Slider
                  min={200}
                  max={4000}
                  step={10}
                  value={[settings.goBeepHz]}
                  onValueChange={([v]) => onUpdate({ goBeepHz: v })}
                />
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label className="text-sm text-muted-foreground">Go-beep length</Label>
                  <span className="text-sm font-mono text-foreground">{(settings.goBeepMs / 1000).toFixed(2)}s</span>
                </div>
                <Slider
                  min={10}
                  max={990}
                  step={10}
                  value={[settings.goBeepMs]}
                  onValueChange={([v]) => onUpdate({ goBeepMs: v })}
                />
              </div>
            </div>
          </section>

          <Separator />

          {/* Display */}
          <section>
            <h3 className="status-text text-muted-foreground mb-3">Display</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <Label htmlFor="statusbar-toggle" className="text-sm text-foreground">Show Status Bar</Label>
                <Switch
                  id="statusbar-toggle"
                  checked={settings.showStatusBar}
                  onCheckedChange={(v) => onUpdate({ showStatusBar: v })}
                />
              </div>

              <div className="space-y-2">
                <Label className="text-sm text-foreground">Clock Font</Label>
                <Select
                  value={settings.clockFont}
                  onValueChange={(v) => onUpdate({ clockFont: v as ClockFont })}
                >
                  <SelectTrigger className="w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.entries(CLOCK_FONTS).map(([key, { label, family }]) => (
                      <SelectItem key={key} value={key}>
                        <span style={{ fontFamily: family }}>{label}</span>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
          </section>
        </div>
      </SheetContent>
    </Sheet>
  );
};

export default SettingsScreen;
