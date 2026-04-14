let audioCtx: AudioContext | null = null;

export function getAudioContext(): AudioContext {
  if (!audioCtx) {
    audioCtx = new AudioContext();
  }
  return audioCtx;
}

export function ensureAudioResumed(): Promise<void> {
  const ctx = getAudioContext();
  if (ctx.state === "suspended") {
    return ctx.resume();
  }
  return Promise.resolve();
}

export function playBeep(frequencyHz: number, durationMs: number) {
  const ctx = getAudioContext();
  if (ctx.state === "suspended") return;

  const osc = ctx.createOscillator();
  const gain = ctx.createGain();

  osc.type = "sine";
  osc.frequency.setValueAtTime(frequencyHz, ctx.currentTime);

  gain.gain.setValueAtTime(0.6, ctx.currentTime);
  // Quick fade out to avoid click
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + durationMs / 1000);

  osc.connect(gain);
  gain.connect(ctx.destination);

  osc.start(ctx.currentTime);
  osc.stop(ctx.currentTime + durationMs / 1000 + 0.01);
}
