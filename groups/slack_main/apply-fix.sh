#!/bin/bash
# Apply the two remaining slack-files bugs fixes
# Run from the NanoClaw project root: bash groups/slack_main/apply-fix.sh

set -e
FILE="src/channels/slack.ts"

echo "🔧 Fix 1: Allow file_share subtype through..."
sed -i "s/if (subtype && subtype !== 'bot_message') return;/if (subtype \&\& subtype !== 'bot_message' \&\& subtype !== 'file_share') return;/" "$FILE"

echo "🔧 Fix 2: Add private botToken property after botUserId..."
sed -i "s/private botUserId: string | undefined;/private botUserId: string | undefined;\n  private botToken: string = '';/" "$FILE"

echo "🔧 Fix 3: Store botToken in constructor (after readEnvFile block)..."
sed -i "s/const botToken = env.SLACK_BOT_TOKEN;/const botToken = env.SLACK_BOT_TOKEN;\n    this.botToken = botToken ?? '';/" "$FILE"

echo "🔧 Fix 4: Use this.botToken instead of this.app.client.token..."
sed -i "s/headers: { Authorization: \`Bearer \${this.app.client.token}\` },/headers: { Authorization: \`Bearer \${this.botToken}\` },/" "$FILE"

echo ""
echo "✅ All fixes applied! Verify with: git diff src/channels/slack.ts"
echo "Then rebuild: npm run build && pm2 restart nanoclaw (or however you restart)"
