#!/usr/bin/env bash
# ============================================================
#  Weekly To-Do Tracker - Terminal Bash Script
#  Storage : tasks.dat   (title|target|done)
#  History : history.log (append-only, blocked by =====)
# ============================================================

set -u

# ---------- Colors ----------
RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
MAGENTA=$'\e[35m'

# ---------- Paths ----------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="$SCRIPT_DIR/tasks.dat"
HIST_FILE="$SCRIPT_DIR/history.log"

[[ -f "$DATA_FILE" ]] || : > "$DATA_FILE"
[[ -f "$HIST_FILE" ]] || : > "$HIST_FILE"

# ============================================================
#  Helpers
# ============================================================

pause() {
    echo
    read -r -p "${DIM}Press Enter to continue...${RESET}" _
}

validate_title() {
    local t="$1"
    [[ -z "$t" ]] && { echo "Title cannot be empty."; return 1; }
    [[ "$t" == *"|"* ]] && { echo "Title cannot contain '|'."; return 1; }
    [[ "$t" =~ ^[[:space:]] || "$t" =~ [[:space:]]$ ]] && { echo "Title cannot start/end with space."; return 1; }
    return 0
}

validate_posint() {
    [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

count_tasks() {
    [[ -s "$DATA_FILE" ]] && wc -l < "$DATA_FILE" | tr -d ' ' || echo 0
}

get_task_line() {
    sed -n "${1}p" "$DATA_FILE"
}

# Count how many weeks are already in history.log
history_week_count() {
    if [[ -s "$HIST_FILE" ]]; then
        grep -c '^===== Week #' "$HIST_FILE" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# ============================================================
#  Rendering
# ============================================================

draw_bar() {
    local done="$1" target="$2"
    local width=10
    local filled
    if (( target <= 0 )); then
        filled=0
    else
        filled=$(( done * width / target ))
        (( filled > width )) && filled=$width
    fi
    local empty=$(( width - filled ))
    local bar=""
    local color
    if (( done == 0 )); then
        color="$RED"
    elif (( done >= target )); then
        color="$GREEN"
    else
        color="$YELLOW"
    fi
    bar+="$color"
    for ((i=0;i<filled;i++)); do bar+="█"; done
    bar+="$RESET$DIM"
    for ((i=0;i<empty;i++)); do bar+="░"; done
    bar+="$RESET"
    printf "%s" "$bar"
}

show_list() {
    clear
    echo "${BOLD}${CYAN}=== Weekly Tasks ===${RESET}"
    echo
    local total_tasks
    total_tasks=$(count_tasks)
    if (( total_tasks == 0 )); then
        echo "${YELLOW}No tasks yet. Add some from the main menu.${RESET}"
        return
    fi

    local sum_target=0 sum_done=0
    while IFS='|' read -r title target done; do
        [[ -z "$title" ]] && continue
        sum_target=$(( sum_target + target ))
        sum_done=$(( sum_done + done ))

        printf "  ${CYAN}›${RESET} %-25s " "$title"
        draw_bar "$done" "$target"
        printf "  %s%d/%d%s\n" "$BOLD" "$done" "$target" "$RESET"
    done < "$DATA_FILE"

    echo
    local pct=0
    (( sum_target > 0 )) && pct=$(( sum_done * 100 / sum_target ))
    echo "${BOLD}Total:${RESET} ${GREEN}${sum_done}${RESET}/${sum_target} sessions (${pct}%)"
}

# ============================================================
#  Actions
# ============================================================

action_add_task() {
    clear
    echo "${BOLD}${CYAN}=== Add Task ===${RESET}"
    echo
    local title target
    while true; do
        read -r -p "Title (English, may contain spaces): " title
        if validate_title "$title"; then break; fi
    done
    while true; do
        read -r -p "Target sessions per week (positive integer): " target
        if validate_posint "$target"; then break; fi
        echo "${RED}Please enter a positive integer.${RESET}"
    done
    echo "${title}|${target}|0" >> "$DATA_FILE"
    echo
    echo "${GREEN}✔ Task added.${RESET}"
    pause
}

action_log_session() {
    clear
    echo "${BOLD}${CYAN}=== Log a Session ===${RESET}"
    echo
    local total
    total=$(count_tasks)
    if (( total == 0 )); then
        echo "${YELLOW}No tasks yet. Add some first.${RESET}"
        pause
        return
    fi

    local -a titles
    local i=1
    while IFS='|' read -r title target done; do
        [[ -z "$title" ]] && continue
        titles+=("$title")
        printf "%2d) %-25s [%d/%d]\n" "$i" "$title" "$done" "$target"
        ((i++))
    done < "$DATA_FILE"

    echo
    local choice
    read -r -p "Which task did you work on? (number, 0 to cancel): " choice
    [[ "$choice" == "0" ]] && return
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#titles[@]} )); then
        echo "${RED}Invalid choice.${RESET}"
        pause
        return
    fi

    local line
    line=$(get_task_line "$choice")
    IFS='|' read -r title target done <<< "$line"
    done=$(( done + 1 ))

    local tmp
    tmp=$(mktemp)
    local j=1
    while IFS='|' read -r t tg d; do
        [[ -z "$t" ]] && continue
        if (( j == choice )); then
            echo "${t}|${tg}|${done}" >> "$tmp"
        else
            echo "${t}|${tg}|${d}" >> "$tmp"
        fi
        ((j++))
    done < "$DATA_FILE"
    mv "$tmp" "$DATA_FILE"

    echo
    echo "${GREEN}✔ Logged 1 session for '${title}'. Now ${done}/${target}.${RESET}"
    pause
}

action_manage_tasks() {
    while true; do
        clear
        echo "${BOLD}${CYAN}=== Manage Tasks ===${RESET}"
        echo
        local total
        total=$(count_tasks)
        if (( total == 0 )); then
            echo "${YELLOW}No tasks yet.${RESET}"
            pause
            return
        fi

        local -a titles
        local i=1
        while IFS='|' read -r title target done; do
            [[ -z "$title" ]] && continue
            titles+=("$title")
            printf "%2d) %-25s [%d/%d]\n" "$i" "$title" "$done" "$target"
            ((i++))
        done < "$DATA_FILE"

        echo
        echo "  0) Back"
        echo
        local choice
        read -r -p "Select a task to edit/delete (0 to go back): " choice
        [[ "$choice" == "0" ]] && return
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#titles[@]} )); then
            echo "${RED}Invalid choice.${RESET}"
            pause
            continue
        fi

        local line
        line=$(get_task_line "$choice")
        IFS='|' read -r title target done <<< "$line"

        echo
        echo "${BOLD}Selected:${RESET} $title  [${done}/${target}]"
        echo
        echo "  1) Edit title"
        echo "  2) Edit target sessions"
        echo "  3) Delete task"
        echo "  0) Cancel"
        echo
        local op
        read -r -p "Choose an option: " op

        case "$op" in
            1)
                local new_title
                while true; do
                    read -r -p "New title (empty to cancel): " new_title
                    [[ -z "$new_title" ]] && break
                    if validate_title "$new_title"; then title="$new_title"; break; fi
                done
                [[ -z "$new_title" ]] && continue
                ;;
            2)
                local new_target
                while true; do
                    read -r -p "New target sessions (positive integer, empty to cancel): " new_target
                    [[ -z "$new_target" ]] && break
                    if validate_posint "$new_target"; then
                        target="$new_target"
                        (( done > target )) && done=$target
                        break
                    fi
                    echo "${RED}Please enter a positive integer.${RESET}"
                done
                [[ -z "$new_target" ]] && continue
                ;;
            3)
                local confirm
                read -r -p "Delete '$title'? [y/N]: " confirm
                [[ "$confirm" =~ ^[Yy]$ ]] || continue
                local tmp
                tmp=$(mktemp)
                local j=1
                while IFS='|' read -r t tg d; do
                    [[ -z "$t" ]] && continue
                    (( j == choice )) || echo "${t}|${tg}|${d}" >> "$tmp"
                    ((j++))
                done < "$DATA_FILE"
                mv "$tmp" "$DATA_FILE"
                echo "${GREEN}✔ Deleted.${RESET}"
                pause
                continue
                ;;
            *)
                continue
                ;;
        esac

        local tmp
        tmp=$(mktemp)
        local j=1
        while IFS='|' read -r t tg d; do
            [[ -z "$t" ]] && continue
            if (( j == choice )); then
                echo "${title}|${target}|${done}" >> "$tmp"
            else
                echo "${t}|${tg}|${d}" >> "$tmp"
            fi
            ((j++))
        done < "$DATA_FILE"
        mv "$tmp" "$DATA_FILE"
        echo "${GREEN}✔ Updated.${RESET}"
        pause
    done
}

action_reset_week() {
    clear
    echo "${BOLD}${CYAN}=== Reset Week ===${RESET}"
    echo
    local total
    total=$(count_tasks)
    if (( total == 0 )); then
        echo "${YELLOW}No tasks to reset.${RESET}"
        pause
        return
    fi

    # Compute stats
    local sum_target=0 sum_done=0
    while IFS='|' read -r title target done; do
        [[ -z "$title" ]] && continue
        sum_target=$(( sum_target + target ))
        sum_done=$(( sum_done + done ))
    done < "$DATA_FILE"

    local pct=0
    (( sum_target > 0 )) && pct=$(( sum_done * 100 / sum_target ))

    echo "This will:"
    echo "  - append a snapshot of the current week to ${BOLD}history.log${RESET}"
    echo "  - set all 'done' counters to 0 (titles and targets kept)"
    echo
    echo "Snapshot preview:"
    echo "  Total: ${sum_done}/${sum_target} sessions (${pct}%)"
    echo
    local confirm
    read -r -p "Proceed? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        pause
        return
    fi

    # Determine week number
    local prev_weeks next_week today
    prev_weeks=$(history_week_count)
    next_week=$(( prev_weeks + 1 ))
    today=$(date +%Y-%m-%d)

    # Append history block
    {
        echo "===== Week #${next_week} ====="
        echo "Reset at: ${today}"
        if (( sum_done == 0 )); then
            echo "Total: 0/${sum_target} sessions (0%)  [no sessions logged]"
        else
            echo "Total: ${sum_done}/${sum_target} sessions (${pct}%)"
        fi
        echo
        local i=1
        while IFS='|' read -r title target done; do
            [[ -z "$title" ]] && continue
            # Plain-text bar for history (no ANSI colors)
            local width=10 filled empty bar
            if (( target <= 0 )); then filled=0; else filled=$(( done * width / target )); (( filled > width )) && filled=$width; fi
            empty=$(( width - filled ))
            bar=""
            for ((k=0;k<filled;k++)); do bar+="█"; done
            for ((k=0;k<empty;k++)); do bar+="░"; done
            printf "%-20s [%s]  %d/%d\n" "$title" "$bar" "$done" "$target"
            ((i++))
        done < "$DATA_FILE"
        echo
    } >> "$HIST_FILE"

    # Zero out done counters
    local tmp
    tmp=$(mktemp)
    while IFS='|' read -r t tg d; do
        [[ -z "$t" ]] && continue
        echo "${t}|${tg}|0" >> "$tmp"
    done < "$DATA_FILE"
    mv "$tmp" "$DATA_FILE"

    echo
    echo "${GREEN}✔ Week #${next_week} archived to history.log.${RESET}"
    echo "${GREEN}✔ All done counters reset to 0.${RESET}"
    pause
}

action_view_history() {
    clear
    echo "${BOLD}${CYAN}=== History ===${RESET}"
    echo
    if [[ ! -s "$HIST_FILE" ]]; then
        echo "${YELLOW}No history yet. Reset a week to start recording.${RESET}"
        pause
        return
    fi
    cat "$HIST_FILE"
    pause
}

# ============================================================
#  Main menu
# ============================================================

main_menu() {
    while true; do
        clear
        echo "${BOLD}${MAGENTA}╔══════════════════════════════════════╗${RESET}"
        echo "${BOLD}${MAGENTA}║       WEEKLY TO-DO TRACKER           ║${RESET}"
        echo "${BOLD}${MAGENTA}╚══════════════════════════════════════╝${RESET}"
        echo
        echo "  ${CYAN}1)${RESET} View weekly list"
        echo "  ${CYAN}2)${RESET} Add a task"
        echo "  ${CYAN}3)${RESET} Log a session"
        echo "  ${CYAN}4)${RESET} Manage tasks (edit/delete)"
        echo "  ${CYAN}5)${RESET} Reset week (archive + zero counters)"
        echo "  ${CYAN}6)${RESET} View history"
        echo "  ${CYAN}0)${RESET} Exit"
        echo

        local choice
        read -r -p "Choose an option: " choice
        case "$choice" in
            1) show_list; pause ;;
            2) action_add_task ;;
            3) action_log_session ;;
            4) action_manage_tasks ;;
            5) action_reset_week ;;
            6) action_view_history ;;
            0) clear; echo "${GREEN}Bye!${RESET}"; exit 0 ;;
            *) echo "${RED}Invalid option.${RESET}"; pause ;;
        esac
    done
}

main_menu
