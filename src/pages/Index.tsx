import { useState } from "react";
import { useSettings } from "@/hooks/useSettings";
import { useTimeSync } from "@/hooks/useTimeSync";
import { useBeepEngine } from "@/hooks/useBeepEngine";
import { useWakeLock } from "@/hooks/useWakeLock";
import ClockDisplay from "@/components/ClockDisplay";
import StatusBar from "@/components/StatusBar";
import BottomBar from "@/components/BottomBar";
import SettingsScreen from "@/components/SettingsScreen";

const Index = () => {
  const { settings, updateSettings } = useSettings();
  const { syncedTime, getSyncedNowMs } = useTimeSync(
    settings.gaFramTidEnabled,
    settings.gaFramTidOffset
  );
  const [settingsOpen, setSettingsOpen] = useState(false);

  useBeepEngine(getSyncedNowMs, settings, syncedTime.syncStatus);
  useWakeLock();

  const isGoSecond = syncedTime.seconds % settings.startInterval === 0;

  return (
    <div className="flex min-h-svh flex-col bg-background">
      <StatusBar
        timeSource={syncedTime.timeSource}
        syncStatus={syncedTime.syncStatus}
        gaFramTidEnabled={settings.gaFramTidEnabled}
        gaFramTidOffset={settings.gaFramTidOffset}
        visible={settings.showStatusBar}
      />

      <ClockDisplay
        time={syncedTime}
        isGoSecond={isGoSecond}
        gaFramTidEnabled={settings.gaFramTidEnabled}
        clockFont={settings.clockFont}
      />

      <BottomBar
        beepsEnabled={settings.beepsEnabled}
        onToggleBeeps={() => updateSettings({ beepsEnabled: !settings.beepsEnabled })}
        onOpenSettings={() => setSettingsOpen(true)}
      />

      <SettingsScreen
        open={settingsOpen}
        onOpenChange={setSettingsOpen}
        settings={settings}
        onUpdate={updateSettings}
        timeSource={syncedTime.timeSource}
        syncStatus={syncedTime.syncStatus}
      />
    </div>
  );
};

export default Index;
