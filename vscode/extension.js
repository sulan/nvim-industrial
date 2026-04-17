'use strict';

// vscode/extension.js
// VSCode extension entry point for nvim-industrial.
// Plays industrial sound effects on editor events using system audio players.
// No npm dependencies — uses only Node.js built-ins.

const vscode = require('vscode');
const { spawn, execSync } = require('child_process');
const { pathToFileURL } = require('url');
const path = require('path');
const fs = require('fs');
const os = require('os');

const SOUNDS_DIR = path.join(__dirname, '..', 'sounds');
const EXTS = ['.ogg', '.wav', '.mp3'];

// ── State ─────────────────────────────────────────────────────────────────────

let audioPlayer = null;
let cfg = {};
let enabled = true;
let lastPlayTimes = {};
let lastGlobalPlay = 0;
let debounceTimers = {};
// Current set of event listener disposables (replaced on config reload).
let eventDisposables = [];

// ── Audio Player Detection ────────────────────────────────────────────────────

function cmdExists(cmd) {
  try {
    const which = os.platform() === 'win32' ? `where "${cmd}"` : `which "${cmd}"`;
    execSync(which, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function findPlayer() {
  const platform = os.platform();
  if (platform === 'darwin') {
    if (cmdExists('afplay')) return 'afplay';
  } else if (platform === 'linux') {
    for (const p of ['paplay', 'pw-play', 'aplay', 'mpv']) {
      if (cmdExists(p)) return p;
    }
  } else if (platform === 'win32') {
    // PowerShell is available on all modern Windows installations.
    return 'powershell.exe';
  }
  return null;
}

// ── Command Builder ───────────────────────────────────────────────────────────

function buildCmd(playerName, filePath, volume) {
  const vol = Math.max(0, Math.min(1, volume));
  switch (playerName) {
    case 'afplay':
      return ['afplay', '-v', vol.toFixed(2), filePath];
    case 'paplay':
      return ['paplay', `--volume=${Math.round(vol * 65536)}`, filePath];
    case 'pw-play':
      return ['pw-play', filePath];
    case 'aplay':
      return ['aplay', '-q', filePath];
    case 'mpv':
      return ['mpv', '--no-terminal', `--volume=${Math.round(vol * 100)}`, filePath];
    case 'powershell.exe': {
      // Windows: WPF MediaPlayer via PowerShell.
      // pathToFileURL produces the correct file:///C:/... URI format.
      const fileUri = pathToFileURL(filePath).href;
      const ps = [
        'Add-Type -AssemblyName presentationCore;',
        `$p = New-Object Windows.Media.Playback.MediaPlayer;`,
        `$p.Volume = ${vol.toFixed(2)};`,
        `$p.Source = [Windows.Media.Core.MediaSource]::CreateFromUri('${fileUri}');`,
        `$p.Play();`,
        'Start-Sleep -Milliseconds 4000',
      ].join(' ');
      return ['powershell.exe', '-WindowStyle', 'Hidden', '-NonInteractive', '-Command', ps];
    }
    default:
      return null;
  }
}

// ── Sound Resolution & Playback ───────────────────────────────────────────────

function resolveSound(name) {
  for (const ext of EXTS) {
    const p = path.join(SOUNDS_DIR, name + ext);
    if (fs.existsSync(p)) return p;
  }
  return null;
}

function spawnDetached(cmd) {
  const proc = spawn(cmd[0], cmd.slice(1), { detached: true, stdio: 'ignore' });
  // unref() lets the child process outlive the extension host — same as
  // Neovim's jobstart({ detach = true }). Critical for the shutdown sound.
  proc.unref();
}

function play(soundName) {
  if (!enabled || !audioPlayer) return;
  if (!soundName) return;

  const now = Date.now();
  const minInterval = cfg.minInterval ?? 80;
  const globalMinInterval = cfg.globalMinInterval ?? 40;

  if (now - (lastPlayTimes[soundName] || 0) < minInterval) return;
  if (now - lastGlobalPlay < globalMinInterval) return;

  const filePath = resolveSound(soundName);
  if (!filePath) return;

  const cmd = buildCmd(audioPlayer, filePath, cfg.volume ?? 0.7);
  if (!cmd) return;

  lastPlayTimes[soundName] = now;
  lastGlobalPlay = now;

  try {
    spawnDetached(cmd);
  } catch {
    // Silently ignore spawn errors — missing player or permissions.
  }
}

// ── Leading-Edge Debounce ─────────────────────────────────────────────────────

// Fires fn immediately on the first call, then suppresses further calls for
// `ms` milliseconds. Mirrors leading_debounced() in events.lua.
function leadingDebounced(key, fn, ms) {
  let suppressed = false;
  return function () {
    if (suppressed) return;
    fn();
    suppressed = true;
    clearTimeout(debounceTimers[key]);
    debounceTimers[key] = setTimeout(() => { suppressed = false; }, ms);
  };
}

// ── Config Loading ────────────────────────────────────────────────────────────

function loadConfig() {
  const c = vscode.workspace.getConfiguration('industrial');
  cfg = {
    enabled:           c.get('enabled', true),
    volume:            Math.max(0, Math.min(1, c.get('volume', 0.7))),
    minInterval:       c.get('minInterval', 80),
    globalMinInterval: c.get('globalMinInterval', 40),
    debounceMs:        c.get('debounceMs', 80),
    events: {
      textChange:  c.get('events.textChange', 'hammer'),
      editorFocus: c.get('events.editorFocus', 'drill_start'),
      save:        c.get('events.save', 'explosion'),
      open:        c.get('events.open', 'rivet'),
      close:       c.get('events.close', 'chainsaw'),
      startup:     c.get('events.startup', 'factory_bell'),
      shutdown:    c.get('events.shutdown', 'factory_shutdown'),
    },
  };
  enabled = cfg.enabled;
}

// ── Event Registration ────────────────────────────────────────────────────────

function registerEvents() {
  // Dispose previous listeners before re-registering (config reload).
  eventDisposables.forEach(d => d.dispose());
  eventDisposables = [];

  const ev = cfg.events;
  const debounceMs = cfg.debounceMs;

  // Text changes → hammer (leading-edge debounce for immediate tactile feedback)
  if (ev.textChange) {
    const handler = leadingDebounced('textChange', () => play(ev.textChange), debounceMs);
    eventDisposables.push(
      vscode.workspace.onDidChangeTextDocument(e => {
        if (e.contentChanges.length > 0 && e.document.uri.scheme === 'file') handler();
      })
    );
  }

  // Switch to a different editor → drill_start
  if (ev.editorFocus) {
    eventDisposables.push(
      vscode.window.onDidChangeActiveTextEditor(editor => {
        if (editor && editor.document.uri.scheme === 'file') play(ev.editorFocus);
      })
    );
  }

  // Save → explosion
  if (ev.save) {
    eventDisposables.push(
      vscode.workspace.onDidSaveTextDocument(doc => {
        if (doc.uri.scheme === 'file') play(ev.save);
      })
    );
  }

  // Open → rivet
  if (ev.open) {
    eventDisposables.push(
      vscode.workspace.onDidOpenTextDocument(doc => {
        if (doc.uri.scheme === 'file') play(ev.open);
      })
    );
  }

  // Close → chainsaw
  if (ev.close) {
    eventDisposables.push(
      vscode.workspace.onDidCloseTextDocument(doc => {
        if (doc.uri.scheme === 'file') play(ev.close);
      })
    );
  }
}

// ── Activate / Deactivate ─────────────────────────────────────────────────────

function activate(context) {
  loadConfig();
  audioPlayer = findPlayer();

  registerEvents();

  // Register event disposables under a single cleanup entry so config-reload
  // replacements don't accumulate dead entries in context.subscriptions.
  context.subscriptions.push({ dispose: () => eventDisposables.forEach(d => d.dispose()) });

  // Startup bell — deferred 200ms so startup I/O doesn't compete with audio.
  if (cfg.events.startup) {
    setTimeout(() => play(cfg.events.startup), 200);
  }

  // Commands
  context.subscriptions.push(
    vscode.commands.registerCommand('industrial.enable', () => {
      enabled = true;
      vscode.window.setStatusBarMessage('Industrial: sounds enabled', 2000);
    }),

    vscode.commands.registerCommand('industrial.disable', () => {
      enabled = false;
      vscode.window.setStatusBarMessage('Industrial: sounds disabled', 2000);
    }),

    vscode.commands.registerCommand('industrial.play', async () => {
      const sounds = fs.existsSync(SOUNDS_DIR)
        ? [...new Set(
            fs.readdirSync(SOUNDS_DIR)
              .filter(f => EXTS.some(e => f.endsWith(e)))
              .map(f => path.basename(f, path.extname(f)))
          )]
        : ['explosion'];
      const picked = await vscode.window.showQuickPick(
        sounds.length ? sounds : ['explosion'],
        { placeHolder: 'Pick a sound to play' }
      );
      if (picked) play(picked);
    }),

    // Reload event listeners when settings change.
    vscode.workspace.onDidChangeConfiguration(e => {
      if (e.affectsConfiguration('industrial')) {
        loadConfig();
        audioPlayer = findPlayer();
        registerEvents();
      }
    })
  );
}

function deactivate() {
  // Best-effort: play shutdown sound as a detached subprocess so it can
  // outlive the extension host process (mirrors Neovim's detach=true).
  const soundName = cfg.events && cfg.events.shutdown;
  if (!soundName || !audioPlayer) return;
  const filePath = resolveSound(soundName);
  if (!filePath) return;
  const cmd = buildCmd(audioPlayer, filePath, cfg.volume ?? 0.7);
  if (!cmd) return;
  try {
    spawnDetached(cmd);
  } catch {
    // best-effort — ignore if player is gone
  }
}

module.exports = { activate, deactivate };
