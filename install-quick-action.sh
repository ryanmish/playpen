#!/bin/bash
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[info]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
error()   { echo -e "${RED}[error]${NC} $*"; }

# ── Variables ───────────────────────────────────────────────────────────────
WORKFLOW_NAME="Claude in Sandbox"
WORKFLOW_DIR="$HOME/Library/Services/${WORKFLOW_NAME}.workflow"
CONTENTS_DIR="${WORKFLOW_DIR}/Contents"

# ── Backup existing workflow if present ─────────────────────────────────────
if [ -d "$WORKFLOW_DIR" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="${WORKFLOW_DIR}.backup.${TIMESTAMP}"
    warn "Existing workflow found. Backing up to: ${BACKUP_DIR}"
    cp -R "$WORKFLOW_DIR" "$BACKUP_DIR"
    rm -rf "$WORKFLOW_DIR"
    success "Backup created"
fi

# ── Create directory structure ──────────────────────────────────────────────
info "Creating workflow bundle at: ${WORKFLOW_DIR}"
mkdir -p "$CONTENTS_DIR"

# ── Write Info.plist ────────────────────────────────────────────────────────
info "Writing Info.plist"
cat > "${CONTENTS_DIR}/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Claude in Sandbox</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSApplicationIdentifier</key>
				<string>com.apple.finder</string>
			</dict>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.folder</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
INFOPLIST

# ── Write document.wflow ───────────────────────────────────────────────────
info "Writing document.wflow"

# The shell script that the Automator action will run.
# This opens Terminal and launches playpen with each selected folder.
# We embed it as CDATA-safe content inside the plist XML.
cat > "${CONTENTS_DIR}/document.wflow" << 'WFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionType</key>
				<string>AMBundleAction</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMCategory</key>
				<string>AMCategoryUtilities</string>
				<key>AMComment</key>
				<string>Launch Claude Code in a sandboxed container for the selected folder.</string>
				<key>AMDescription</key>
				<dict>
					<key>AMDInput</key>
					<string>The files and folders to process.</string>
					<key>AMDSummary</key>
					<string>Runs a shell script with the selected folders.</string>
				</dict>
				<key>AMIconName</key>
				<string>TerminalAction</string>
				<key>AMKeywords</key>
				<array>
					<string>shell</string>
					<string>script</string>
					<string>command</string>
					<string>run</string>
					<string>terminal</string>
				</array>
				<key>AMName</key>
				<string>Run Shell Script</string>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>for f in "$@"; do
    escaped=$(printf '%s' "$f" | sed "s/'/'\\\\''/g")
    osascript -e "
        tell application \"Terminal\"
            activate
            do script \"$HOME/.local/bin/playpen '${escaped}'\"
        end tell
    "
done</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>A7B4C8D1-2E3F-4A5B-6C7D-8E9F0A1B2C3D</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>B8C5D9E2-3F4A-5B6C-7D8E-9F0A1B2C3D4E</string>
				<key>UUID</key>
				<string>C9D6EA03-4A5B-6C7D-8E9F-0A1B2C3D4E5F</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>0</string>
					</dict>
					<key>1</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>source</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>4</string>
						<key>uuid</key>
						<string>1</string>
					</dict>
					<key>2</key>
					<dict>
						<key>default value</key>
						<false/>
						<key>name</key>
						<string>CheckedForUserDefaultShell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>2</string>
					</dict>
					<key>3</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>COMMAND_STRING</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>4</string>
						<key>uuid</key>
						<string>3</string>
					</dict>
					<key>4</key>
					<dict>
						<key>default value</key>
						<string>/bin/sh</string>
						<key>name</key>
						<string>shell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>4</string>
						<key>uuid</key>
						<string>4</string>
					</dict>
				</dict>
				<key>is498</key>
				<true/>
				<key>is498bundle</key>
				<true/>
				<key>outputTypeIdentifier</key>
				<string>com.apple.cocoa.string</string>
			</dict>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceApplicationGroupName</key>
		<string>Finder</string>
		<key>serviceApplicationPath</key>
		<string>/System/Library/CoreServices/Finder.app</string>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.fileSystemObject</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>systemImageName</key>
		<string>NSActionTemplate</string>
		<key>useAutomaticInputType</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

# ── Rebuild the Launch Services database so macOS picks up the new action ───
info "Refreshing Launch Services database (this may take a moment)..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
success "Quick Action \"${WORKFLOW_NAME}\" installed successfully!"
echo ""
info "To use it:"
echo "    1. Right-click any folder in Finder"
echo "    2. Look for Quick Actions > \"${WORKFLOW_NAME}\""
echo ""
warn "If it doesn't appear, enable it in:"
echo "    System Settings > Privacy & Security > Extensions > Finder Extensions"
echo "    (or System Settings > Extensions > Finder on older macOS versions)"
echo ""
info "The action will open Terminal and launch playpen with the selected folder."
