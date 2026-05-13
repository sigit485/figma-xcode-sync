// code.ts — runs in Figma plugin sandbox
// Has access to Figma API but NO DOM, NO fetch

const COMPANION_PORT = 9876;

figma.showUI(__html__, { width: 380, height: 560, title: "Xcode Asset Sync" });

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getPageName(): string {
  return figma.currentPage.name.toLowerCase().replace(/\s+/g, "_");
}

function buildIconName(node: SceneNode, pageName: string): string {
  const cleanName = node.name
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  return `${pageName}_ic_${cleanName}`;
}

function getSelectedIconNodes(): SceneNode[] {
  return figma.currentPage.selection.filter(
    (node) =>
      node.type === "FRAME" ||
      node.type === "COMPONENT" ||
      node.type === "INSTANCE" ||
      node.type === "GROUP" ||
      node.type === "VECTOR"
  );
}

// ─── Export single node at a given scale ──────────────────────────────────────

async function exportNodeAsBytes(
  node: SceneNode,
  format: "PNG" | "SVG",
  scale: number
): Promise<string> {
  const settings: ExportSettings =
    format === "PNG"
      ? { format: "PNG", constraint: { type: "SCALE", value: scale } }
      : { format: "SVG", svgOutlineText: false, svgIdAttribute: true };

  const bytes = await node.exportAsync(settings);
  // Convert Uint8Array to base64
  let binary = "";
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

// ─── Main export handler ──────────────────────────────────────────────────────

async function exportSelectedIcons(
  format: "PNG" | "SVG",
  renderingMode: "original" | "template"
) {
  const nodes = getSelectedIconNodes();
  if (nodes.length === 0) {
    figma.ui.postMessage({ type: "error", message: "No icon frames selected." });
    return;
  }

  const pageName = getPageName();
  figma.ui.postMessage({ type: "export-start", count: nodes.length });

  const icons: IconPayload[] = [];

  for (let i = 0; i < nodes.length; i++) {
    const node = nodes[i];
    const iconName = buildIconName(node, pageName);

    figma.ui.postMessage({
      type: "export-progress",
      current: i + 1,
      total: nodes.length,
      name: iconName,
    });

    try {
      if (format === "PNG") {
        const [x1, x2, x3] = await Promise.all([
          exportNodeAsBytes(node, "PNG", 1),
          exportNodeAsBytes(node, "PNG", 2),
          exportNodeAsBytes(node, "PNG", 3),
        ]);
        icons.push({
          name: iconName,
          module: pageName,
          format: "png",
          renderingMode,
          scales: { "1x": x1, "2x": x2, "3x": x3 },
        });
      } else {
        const svgData = await exportNodeAsBytes(node, "SVG", 1);
        icons.push({
          name: iconName,
          module: pageName,
          format: "svg",
          renderingMode,
          data: svgData,
        });
      }
    } catch (err) {
      figma.ui.postMessage({
        type: "export-item-error",
        name: iconName,
        error: String(err),
      });
    }
  }

  figma.ui.postMessage({ type: "export-ready", icons, pageName });
}

// ─── Preview: list selected nodes before export ───────────────────────────────

function sendSelectionPreview() {
  const nodes = getSelectedIconNodes();
  const pageName = getPageName();
  const preview = nodes.map((n) => ({
    id: n.id,
    name: n.name,
    iconName: buildIconName(n, pageName),
    width: "width" in n ? n.width : 0,
    height: "height" in n ? n.height : 0,
  }));
  figma.ui.postMessage({ type: "selection-preview", items: preview, pageName });
}

// ─── Listen to Figma selection changes ────────────────────────────────────────

figma.on("selectionchange", sendSelectionPreview);
sendSelectionPreview(); // initial

// ─── Message handler from UI ──────────────────────────────────────────────────

figma.ui.onmessage = async (msg: PluginMessage) => {
  switch (msg.type) {
    case "export":
      await exportSelectedIcons(msg.format, msg.renderingMode);
      break;

    case "get-selection":
      sendSelectionPreview();
      break;

    case "close":
      figma.closePlugin();
      break;
  }
};

// ─── Types ────────────────────────────────────────────────────────────────────

interface IconPayload {
  name: string;
  module: string;
  format: "png" | "svg";
  renderingMode: "original" | "template";
  scales?: { "1x": string; "2x": string; "3x": string };
  data?: string;
}

type PluginMessage =
  | { type: "export"; format: "PNG" | "SVG"; renderingMode: "original" | "template" }
  | { type: "get-selection" }
  | { type: "close" };
