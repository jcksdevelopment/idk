import { PageHeader } from "@/components/ui";
import { VisionVault } from "@/components/vision-vault";

export const metadata = { title: "Vision Vault · Sentinel" };

export default function VisionPage() {
  return (
    <>
      <PageHeader title="Vision Vault" description="Screens captured from suspicious players and the AI evaluator's verdict on each." />
      <VisionVault />
    </>
  );
}
