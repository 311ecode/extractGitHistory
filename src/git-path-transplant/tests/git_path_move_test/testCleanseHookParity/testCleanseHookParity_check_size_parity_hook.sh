#!/usr/bin/env bash
testCleanseHookParity_check_size_parity_hook() {
  local src="$1"
  local dst="$2"
  
  echo "🔍 Hook: Validating size parity between $src and $dst"
  
  local src_size=$(du -sb "$src" | cut -f1)
  local dst_size=$(du -sb "$dst" | cut -f1)
  
  if [[ "$src_size" == "$dst_size" ]]; then
    echo "✅ Hook: Sizes match ($src_size bytes). Proceeding."
    return 0
  else
    echo "❌ Hook: SIZE MISMATCH! (Src: $src_size, Dst: $dst_size)"
    return 1
  fi
}