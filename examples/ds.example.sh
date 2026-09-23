# Profile: DeepSeek
# Provider: DeepSeek Official Anthropic-Compatible Endpoint
#
# Start with the Pro model by default. Claude Code can switch model tiers
# within a session via /model, or at startup with --model haiku|sonnet|opus.
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_MODEL="DeepSeek-V4-Pro"

# Claude Code tier-to-provider-model mapping
export ANTHROPIC_DEFAULT_OPUS_MODEL="DeepSeek-V4-Pro"
export ANTHROPIC_DEFAULT_SONNET_MODEL="DeepSeek-V4-Pro"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash"
export ANTHROPIC_REASONING_MODEL="DeepSeek-V4-Pro"
