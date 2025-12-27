testRelativeUpwardMove() {
    echo "🧪 Testing Relative Upward Move (../../)"
    local tmp_dir=$(mktemp -d)
    mkdir -p "$tmp_dir/repo/work/current"
    cd "$tmp_dir/repo" && git init -q
    git config user.email "t@t.com" && git config user.name "T"
    echo "d" > work/current/f.txt && git add . && git commit -m "d" -q
    
    cd "$tmp_dir/repo/work/current"
    # The fix: Ensure we use the function with the relative path correctly resolved
    git_path_move "." "../../archive/legacy"
    
    cd "$tmp_dir/repo"
    [[ ! -f "archive/legacy/f.txt" ]] && return 1
    [[ -d "work/current" ]] && return 1
    return 0
  }