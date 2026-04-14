import { Volume2, VolumeX, Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ensureAudioResumed } from "@/lib/audioEngine";

interface BottomBarProps {
  beepsEnabled: boolean;
  onToggleBeeps: () => void;
  onOpenSettings: () => void;
}

const BottomBar = ({ beepsEnabled, onToggleBeeps, onOpenSettings }: BottomBarProps) => {
  const handleToggleBeeps = async () => {
    await ensureAudioResumed();
    onToggleBeeps();
  };

  return (
    <div className="flex w-full items-center justify-between px-4 py-4">
      <Button
        variant="ghost"
        size="icon"
        className="h-11 w-11 text-muted-foreground hover:text-foreground"
        onClick={handleToggleBeeps}
        aria-label={beepsEnabled ? "Mute beeps" : "Enable beeps"}
      >
        {beepsEnabled ? <Volume2 className="!h-6 !w-6" /> : <VolumeX className="!h-6 !w-6" />}
      </Button>
      <Button
        variant="ghost"
        size="icon"
        className="h-11 w-11 text-muted-foreground hover:text-foreground"
        onClick={onOpenSettings}
        aria-label="Settings"
      >
        <Settings className="!h-6 !w-6" />
      </Button>
    </div>
  );
};

export default BottomBar;
