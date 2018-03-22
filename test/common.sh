
export CATALOG=$HOME/.dbdeployer/sandboxes.json

if [ -n "$SKIP_DBDEPLOYER_CATALOG" ]
then
    echo "This test requires dbdeployer catalog to be enabled"
    echo "Unset the variable SKIP_DBDEPLOYER_CATALOG to continue"
    exit 1
fi

dbdeployer_version=$(dbdeployer --version)
if [ -z "$dbdeployer_version" ]
then
    echo "dbdeployer not found"
    exit 1
fi

[ -z "$results_log" ] && export results_log=results-$(uname).txt

function start_timer {
    start=$(date)
    start_sec=$(date +%s)
    date > "$results_log"
}

function minutes_seconds {
    secs=$1
    elapsed_minutes=$((secs/60))
    remainder=$((secs-elapsed_minutes*60))
    printf "%dm:%02ds" ${elapsed_minutes} ${remainder}
}

function stop_timer {
    stop=$(date)
    stop_sec=$(date +%s)
    elapsed=$(($stop_sec-$start_sec))
    echo "OS:  $(uname)"
    echo "OS:  $(uname)" >> "$results_log"
    echo "Started: $start"
    echo "Started: $start" >> "$results_log"
    echo "Ended  : $stop"
    echo "Ended  : $stop" >> "$results_log"
    echo "Elapsed: $elapsed seconds ($(minutes_seconds $elapsed))"
    echo "Elapsed: $elapsed seconds" >> "$results_log"
}

function show_catalog {
    if [ -f "$CATALOG" ]
    then
        cat "$CATALOG"
    fi
}

function count_catalog {
    show_catalog | grep destination | wc -l | tr -d ' '
}

function list_active_tests {
    echo "Enabled tests:"
    if [ -z "$skip_main_deployment_methods" ]
    then
        echo main_deployment_methods
    fi
    if [ -z "$skip_pre_post_operations" ]
    then
        echo pre_post_operations
    fi
    if [ -z "$skip_group_operations" ]
    then
        echo group_operations
    fi
    if [ -z "$skip_multi_source_operations" ]
    then
        echo multi_source_operations
    fi
    echo "Current test: $current_test"
    echo ""
    concurrency=no
    if [ -n "$RUN_CONCURRENTLY" ]
    then
        concurrency=yes
    fi
    echo "Runs concurrently: $concurrency"
    echo ""
}



function user_input {
    answer=""
    while [ "$answer" != "continue" ]
    do
        echo "Press ENTER to continue or choose among { s c q i o r u h t }"
        read answer
        case $answer in
            [cC])
                unset INTERACTIVE
                echo "Now running unattended"
                return
                ;;
            [qQ])
                echo "Interrupted at user's request"
                exit 0
                ;;
            [iI])
                echo inspecting
                show_catalog
                ;;
            [oO])
                echo counting
                count_catalog
                ;;
            [sS])
                echo show sandboxes
                dbdeployer sandboxes --catalog
                ;;
            [rR])
                echo "Enter global command to run"
                echo "Choose among : start restart stop status test test-replication"
                read cmd
                dbdeployer global $cmd
                if [ "$?" != "0" ]
                then
                    exit 1
                fi
                ;;
            [uU])
                echo "Enter query to run"
                read cmd
                dbdeployer global use "$cmd"
                if [ "$?" != "0" ]
                then
                    exit 1
                fi
                ;;
            [tT])
                list_active_tests
                ;;
            [hH])
                echo "Commands:"
                echo "c : continue (end interactivity)"
                echo "i : inspect sandbox catalog"
                echo "o : count sandbox instances"
                echo "q : quit the test immediately"
                echo "r : run 'dbdeployer global' command"
                echo "u : run 'dbdeployer global use' query"
                echo "s : show sandboxes"
                echo "t : list active tests"
                echo "h : display this help"
                ;;
            *)
                answer="continue"
        esac
    done
}

function results {
    echo "#$*"
    echo "#$*" >> "$results_log"
    echo "dbdeployer sandboxes --catalog"
    echo "dbdeployer sandboxes --catalog" >> "$results_log"
    dbdeployer sandboxes --catalog
    dbdeployer sandboxes --catalog >> "$results_log"
    echo ""
    echo "" >> "$results_log"
    echo "catalog: $(count_catalog)"
    echo "catalog: $(count_catalog)" >> "$results_log"
    if [ -n "$INTERACTIVE" ]
    then
        user_input
    fi
}

function ok_comparison {
    op=$1
    label=$2
    value1=$3
    value2=$4
    unset success
    unset failure
    if [ -z "$value1"  -o -z "$value2" ]
    then
        echo "ok_$op: empty value passed"
        exit 1
    fi
    case $op in
        equal)
            if [ "$value1" == "$value2" ]
            then
                success="ok - $label found '$value1' - expected: '$value2' "
            else
                failure="not ok - $label found '$value1' - expected: '$value2' "
            fi
            ;;
        greater)
            if [[ $value1 -gt $value2 ]]
            then
                success="ok - $label  '$value1' > '$value2' "
            else
                failure="not ok - $label  '$value1' not > '$value2' "
            fi
            ;;
        greater_equal)
            if [[ $value1 -ge $value2 ]]
            then
                success="ok - $label  '$value1' >= '$value2' "
            else
                failure="not ok - $label  '$value1' not >= '$value2' "
            fi
            ;;
        *)
            echo "Unsupported operation '$op'"
            exit 1
    esac
    if [ -n "$success" ]
    then
        echo $success
        pass=$((pass+1))
    elif [ -n "$failure" ]
    then
        echo $failure
        fail=$((fail+1))
    else
        echo "Neither success or failure detected"
        echo "op:     $op"
        echo "label:  $label"
        echo "value1: $value1 "
        echo "value2: $value2 "
        exit 1
    fi
    tests=$((tests+1))
}

function ok_equal {
    label=$1
    value1=$2
    value2=$3
    ok_comparison equal "$label" "$value1" "$value2"
}

function ok_greater {
    label="$1"
    value1=$2
    value2=$3
    ok_comparison greater "$label" "$value1" "$value2"
}

function ok_greater_equal {
    label="$1"
    value1=$2
    value2=$3
    ok_comparison greater_equal "$label" "$value1" "$value2"
}

function ok_contains {
    label=$1
    value1=$2
    value2=$3
    contains=$(echo "$value1" |grep "$value2")
    if [ -n "$contains" ]
    then
        echo "ok - $label - '$value1' contains '$value2' "
        pass=$((pass+1))
    else
        echo "not ok - $label - '$value1' does not contain '$value2' "
        fail=$((fail+1))
    fi
    tests=$((tests+1))
}

function ok {
    label=$1
    value=$2
    if [ -n "$value" ]
    then
        echo "ok - $label "
        pass=$((pass+1))
    else
        echo "not ok - $label "
        fail=$((fail+1))
    fi
    tests=$((tests+1))
}

function run {
    temp_stop_sec=$(date +%s)
    temp_elapsed=$(($temp_stop_sec-$start_sec))
    echo "+ $(date) (${temp_elapsed}s)"
    echo "+ $(date) (${temp_elapsed}s)" >> "$results_log"
    echo "# $*" >> "$results_log"
    (set -x
    $@
    )
    exit_code=$?
    echo $exit_code
    if [ "$exit_code" != "0" ]
    then
        exit $exit_code
    fi
}


