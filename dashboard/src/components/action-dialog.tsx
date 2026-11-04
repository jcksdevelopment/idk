"use client";

import { useState } from "react";
import { postAction } from "@/lib/client";
import { Button, Dialog, Input } from "./ui";

export type PendingAction = { type: "ban" | "kick" | "screenshot"; player: number; serverId: string; name: string } | null;

const DURATIONS: [string, number | undefined][] = [
  ["Permanent", undefined],
  ["1 day", 24],
  ["7 days", 168],
  ["30 days", 720],
];

export function ActionDialog({ action, onClose, onDone }: { action: PendingAction; onClose: () => void; onDone: (msg: string) => void }) {
  const [reason, setReason] = useState("");
  const [duration, setDuration] = useState<number | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const close = () => {
    setReason("");
    setDuration(undefined);
    setError(null);
    onClose();
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!action) return;
    setBusy(true);
    setError(null);
    try {
      const r = await postAction({ type: action.type, player: action.player, serverId: action.serverId, reason: reason || undefined, durationHours: duration });
      onDone(`${action.type} queued for ${action.name}${r.delivered === "queued-offline" ? " (game server offline, will deliver on reconnect)" : ""}`);
      close();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const title = action ? { ban: `Ban ${action.name}`, kick: `Kick ${action.name}`, screenshot: `Capture ${action.name}'s screen` }[action.type] : "";

  return (
    <Dialog open={!!action} onClose={close} title={title}>
      <form onSubmit={submit} className="space-y-4 px-5 py-4">
        {action?.type === "screenshot" ? (
          <p className="text-sm text-muted">Requests a frame from the player&apos;s game. If AI vision is configured, the verdict lands in the Vision Vault.</p>
        ) : (
          <label className="block space-y-1.5">
            <span className="text-xs text-muted">Reason{action?.type === "ban" ? "" : " (optional)"}</span>
            <Input required={action?.type === "ban"} value={reason} onChange={(e) => setReason(e.target.value)} placeholder={action?.type === "ban" ? "Shown to the player when they try to reconnect" : "Shown to the player"} maxLength={200} autoFocus />
          </label>
        )}
        {action?.type === "ban" && (
          <fieldset className="space-y-1.5">
            <legend className="text-xs text-muted">Duration</legend>
            <div className="grid grid-cols-4 gap-1.5">
              {DURATIONS.map(([label, hours]) => (
                <button
                  type="button"
                  key={label}
                  onClick={() => setDuration(hours)}
                  aria-pressed={duration === hours}
                  className="h-8 rounded-md border border-line-strong text-xs text-muted aria-pressed:border-zinc-400 aria-pressed:bg-elevated aria-pressed:text-fg"
                >
                  {label}
                </button>
              ))}
            </div>
          </fieldset>
        )}
        {error && <p className="text-sm text-red-400">{error}</p>}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" onClick={close}>
            Cancel
          </Button>
          <Button type="submit" variant={action?.type === "ban" ? "danger" : "primary"} disabled={busy}>
            {busy ? "Sending…" : action?.type === "ban" ? "Ban player" : action?.type === "kick" ? "Kick player" : "Request capture"}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
