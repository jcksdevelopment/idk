import { PageHeader } from "@/components/ui";
import { SettingsEditor } from "@/components/settings-editor";
import { IntegrationSuggestions } from "@/components/integration-suggestions";

export const metadata = { title: "Settings · JCKS Anticheat" };

export default function SettingsPage() {
  return (
    <>
      <PageHeader title="Settings" description="Live anticheat settings. Saving sends them to the game server, which validates, writes config.json and applies them without a restart." />
      <IntegrationSuggestions />
      <SettingsEditor />
    </>
  );
}
