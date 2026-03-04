name: legacy-issues-migration
description: "Migrate open issues from legacy repos to The-Nexus monorepo"
version: "1.0"
args:
  - name: dry_run
    type: bool
    default: true
  - name: close_legacy
    type: bool
    default: false

steps:
  - id: migrate
    description: "Discover, create, optionally close legacy issues"
    command: |
      #!/bin/sh
      DRY="${dry_run}"
      CLOSE="${close_legacy}"
      REPOS="Pryan-Fire Arianus-Sky Chelestra-Sea Abarrach-Stone Nexus-Vaults"
      WORKDIR="/data/openclaw/workspace/.lobster"
      mkdir -p "$WORKDIR"
      LEGACY="$WORKDIR/legacy-issues.jsonl"
      MAP="$WORKDIR/issue-mapping.txt"

      # Discover (overwrite any existing)
      rm -f "$LEGACY"
      for r in $REPOS; do
        (gh issue list --repo The-Nexus-Decoded/$r --state open --json number,title,body,labels --limit 100 2>/dev/null || true) \
          | jq -c --arg repo "$r" '.[] | . + {repo: $repo}' >> "$LEGACY"
      done
      TOTAL=$(wc -l < "$LEGACY" 2>/dev/null || echo 0)

      if [ "$DRY" = "true" ]; then
        echo "DRY RUN: Would migrate $TOTAL issues from legacy repos to The-Nexus."
        echo "Sample:"
        head -3 "$LEGACY" | jq -r '"\(.repo)#\(.number): \(.title)"' 2>/dev/null || head -3 "$LEGACY"
        exit 0
      fi

      echo "Creating $TOTAL issues in The-Nexus..."
      echo "old_repo,old_num,new_num,title" > "$MAP"
      count=0
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        repo=$(echo "$line" | jq -r '.repo')
        old=$(echo "$line" | jq -r '.number')
        title=$(echo "$line" | jq -r '.title')
        body=$(echo "$line" | jq -r '.body // ""')

        # Labels: preserve priority:/type:, add area:
        labels=$(echo "$line" | jq -r '.labels[].name' | grep -E '^(priority:|type:)' | paste -sd, -)
        case "$repo" in
          Pryan-Fire) area=area:fire ;;
          Arianus-Sky) area=area:sky ;;
          Chelestra-Sea) area=area:sea ;;
          Abarrach-Stone) area=area:stone ;;
          Nexus-Vaults) area=area:vaults ;;
          *) area= ;;
        esac
        [ -n "$labels" ] && labels="$labels,$area" || labels="$area"

        count=$((count+1))
        echo "[$count/$TOTAL] $repo #$old: $title"
        url=$(gh issue create --repo The-Nexus-Decoded/The-Nexus \
          --title "[$repo] $title" \
          --body "$body" \
          $(printf -- '--label %s ' $(echo "$labels" | tr ',' '\n')) \
          2>/dev/null || echo "error")
        new=$(echo "$url" | grep -oE '[0-9]+$' || echo "?")
        echo "$repo,$old,$new,$title" >> "$MAP"
      done < "$LEGACY"

      echo "Mapping saved to $MAP"
      head -10 "$MAP"

      if [ "$CLOSE" = "true" ]; then
        echo "Closing legacy issues with redirects..."
        while IFS=, read -r r o n t; do
          [ "$r" = "old_repo" ] && continue
          [ "$n" = "?" ] && continue
          eval "map_${r}_${o}=\"$n\""
        done < "$MAP"

        for r in $REPOS; do
          gh issue list --repo The-Nexus-Decoded/$r --state open --json number --limit 100 2>/dev/null || true \
            | jq -r '.[].number' | while read -r old; do
              new=$(eval "echo \${map_${r}_${old}-}")
              if [ -n "$new" ] && [ "$new" != "?" ]; then
                echo "Closing $r#$old -> The-Nexus#$new"
                gh issue close "$old" --repo The-Nexus-Decoded/$r \
                  --comment "Migrated to The-Nexus#$new. https://github.com/The-Nexus-Decoded/The-Nexus/issues/$new" || true
              fi
            done
        done

        echo "Updating ACTIVE-TASKS.md..."
        TASKS="/data/openclaw/workspace/ACTIVE-TASKS.md"
        if [ -f "$TASKS" ]; then
          cp "$TASKS" "$TASKS.bak-$(date +%Y%m%d-%H%M%S)"
          while IFS=, read -r r o n t; do
            [ "$r" = "old_repo" ] && continue
            [ "$n" = "?" ] && continue
            old="${r}#${o}"
            new="The-Nexus#$n"
            sed -i "s|$old|$new|g" "$TASKS" 2>/dev/null || true
          done < "$MAP"
          echo "ACTIVE-TASKS.md updated with new issue references."
          grep -E 'The-Nexus#[0-9]+' "$TASKS" | head -5 || true
        else
          echo "ACTIVE-TASKS.md not found, skipping"
        fi
      else
        echo "Skipping close and update (close_legacy=false)."
      fi

      echo "=== Migration complete ==="
    timeoutMs: 600000