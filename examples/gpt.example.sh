# Profile: GPT
# Provider: OpenAI GPT via an Anthropic-compatible gateway
#
# Define the gateway's model-tier mapping once. Claude Code can then switch
# tiers with /model, or select one at startup with --model haiku|sonnet|opus.
export ANTHROPIC_BASE_URL="https://YOUR_GATEWAY_URL"
export ANTHROPIC_MODEL="YOUR_MEDIUM_MODEL_HERE"

# Claude Code tier-to-provider-model mapping
export ANTHROPIC_DEFAULT_OPUS_MODEL="YOUR_HIGHEST_AVAILABLE_MODEL_HERE"
export ANTHROPIC_DEFAULT_SONNET_MODEL="YOUR_MEDIUM_MODEL_HERE"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="YOUR_LOW_COST_MODEL_HERE"
export ANTHROPIC_REASONING_MODEL="YOUR_HIGHEST_AVAILABLE_MODEL_HERE"
