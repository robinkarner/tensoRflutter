/// KI-Schicht (K-3) — Barrel.
///
/// Port von `js/enhance.js` + `js/claude.js`: Flow-Registry (7 Flows),
/// Generate-GPT-Hub (Topbar-Popover-Inhalt), Werkbank-Panel (rechts
/// einfahrend), ✦ Magic-Dock, pasteModal/infoModal/standModal,
/// Claude-SSE-Client + Demo-Modus.
///
/// Andockflächen für andere Pakete:
///  * [GptHubCard] — Inhalt des gpt-pop der Topbar (`Enhance.hub`).
///  * [openEnhancePanel] — die Werkbank (`Enhance.open`).
///  * [AiMagicDock] — das kompakte Bedien-Modul je Stelle (`Enhance.dock`).
///  * [showAiPasteModal] / [showAiInfoModal] / [showAiStandModal].
///  * [showClaudeConfigModal] — „GPT Magic — Zugang einrichten“.
///  * [wireAiHooks] — füllt die K-3-Anker (Quellen-Magic-Bar, ↻ Views);
///    aufgerufen von `wireAppSlots()` in lib/app_wiring.dart.
library;

export 'client/claude_cfg.dart'
    show
        AiAccessDot,
        AiAccessInfo,
        ClaudeCfg,
        ClaudeCfgStore,
        EnhCfgStore,
        aiAccessInfo,
        claudeCfgStoreProvider,
        enhCfgStoreProvider;
export 'client/claude_client.dart'
    show
        AiAbortException,
        AiCancelToken,
        ClaudeClient,
        ClaudeEstimate,
        ClaudeRunResult,
        ClaudeUsage,
        claudeClean,
        claudeClientProvider,
        claudeEstimate,
        costOf,
        estOutTokens,
        estTokens;
export 'client/claude_models.dart';
export 'dock/magic_dock.dart' show AiMagicDock, AiRunHandle;
export 'flows/ai_flow.dart';
export 'flows/checkers.dart';
export 'flows/marks_prompt.dart';
export 'flows/registry.dart';
export 'hub/gpt_hub.dart' show GptHubCard, aiHubCtx;
export 'panel/claude_cfg_form.dart' show ClaudeCfgForm, showClaudeConfigModal;
export 'panel/enhance_panel.dart' show openEnhancePanel;
export 'paste_modal/info_modal.dart' show showAiInfoModal;
export 'paste_modal/paste_modal.dart' show showAiPasteModal;
export 'paste_modal/stand_modal.dart' show showAiStandModal;
export 'widgets/ai_magic_bar.dart' show AiMagicBar;
export 'wiring.dart' show aiViewGenerate, wireAiHooks;
