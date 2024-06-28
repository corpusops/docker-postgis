#!/usr/bin/env bash
set -e
shopt -s extglob
export DOCKER_BUILDKIT=${DOCKER_BUILDKIT-1}
export COMPOSE_DOCKER_CLI_BUILD=${COMPOSE_DOCKER_CLI_BUILD-1}
export BUILDKIT_PROGRESS=${BUILDKIT_PROGRESS-plain}
## refresh from corpsusops.bootstrap/hacking/shell_glue (copy paste until last function)
readlinkf() {
    if ( uname | grep -E -iq "darwin|bsd" );then
        if ( which greadlink 2>&1 >/dev/null );then
            greadlink -f "$@"
        elif ( which perl 2>&1 >/dev/null );then
            perl -MCwd -le 'print Cwd::abs_path shift' "$@"
        elif ( which python 2>&1 >/dev/null );then
            python -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$@"
        fi
    else
        readlink -f "$@"
    fi
}
# colors
RED="\\e[0;31m"
CYAN="\\e[0;36m"
YELLOW="\\e[0;33m"
NORMAL="\\e[0;0m"
NO_COLOR=${NO_COLORS-${NO_COLORS-${NOCOLOR-${NOCOLORS-}}}}
LOGGER_NAME=${LOGGER_NAME:-corpusops_build}
ERROR_MSG="There were errors"
uniquify_string() {
    local pattern=$1
    shift
    echo "$@" \
        | sed -e "s/${pattern}/\n/g" \
        | awk '!seen[$0]++' \
        | tr "\n" "${pattern}" \
        | sed -e "s/^${pattern}\|${pattern}$//g"
}
do_trap_() { rc=$?;func=$1;sig=$2;${func};if [ "x${sig}" != "xEXIT" ];then kill -${sig} $$;fi;exit $rc; }
do_trap() { rc=${?};func=${1};shift;sigs=${@};for sig in ${sigs};do trap "do_trap_ ${func} ${sig}" "${sig}";done; }
is_ci() { return $( set +e;( [ "x${TRAVIS-}" != "x" ] || [ "x${GITLAB_CI}" != "x" ] );echo $?; ); }
log_() {
    reset_colors;msg_color=${2:-${YELLOW}};
    logger_color=${1:-${RED}};
    logger_slug="${logger_color}[${LOGGER_NAME}]${NORMAL} ";
    shift;shift;
    if [ "x${NO_LOGGER_SLUG}" != "x" ];then logger_slug="";fi
    printf "${logger_slug}${msg_color}$(echo "${@}")${NORMAL}\n" >&2;
    printf "" >&2;  # flush
}
reset_colors() { if [ "x${NO_COLOR}" != "x" ];then BLUE="";YELLOW="";RED="";CYAN="";fi; }
log() { log_ "${RED}" "${CYAN}" "${@}"; }
get_chrono() { date "+%F_%H-%M-%S"; }
cronolog() { log_ "${RED}" "${CYAN}" "($(get_chrono)) ${@}"; }
debug() { if [ "x${DEBUG-}" != "x" ];then log_ "${YELLOW}" "${YELLOW}" "${@}"; fi; }
warn() { log_ "${RED}" "${CYAN}" "${YELLOW}[WARN] ${@}${NORMAL}"; }
bs_log(){ log_ "${RED}" "${YELLOW}" "${@}"; }
bs_yellow_log(){ log_ "${YELLOW}" "${YELLOW}" "${@}"; }
may_die() {
    reset_colors
    thetest=${1:-1}
    rc=${2:-1}
    shift
    shift
    if [ "x${thetest}" != "x0" ]; then
        if [ "x${NO_HEADER-}" = "x" ]; then
            NO_LOGGER_SLUG=y log_ "" "${CYAN}" "Problem detected:"
        fi
        NO_LOGGER_SLUG=y log_ "${RED}" "${RED}" "$@"
        exit $rc
    fi
}
die() { may_die 1 1 "${@}"; }
die_in_error_() {
    ret=${1}; shift; msg="${@:-"$ERROR_MSG"}";may_die "${ret}" "${ret}" "${msg}";
}
die_in_error() { die_in_error_ "${?}" "${@}"; }
die_() { NO_HEADER=y die_in_error_ $@; }
sdie() { NO_HEADER=y die $@; }
parse_cli() { parse_cli_common "${@}"; }
parse_cli_common() {
    USAGE=
    local i=
    for i in ${@-};do
        case ${i} in
            --no-color|--no-colors|--nocolor|--no-colors)
                NO_COLOR=1;;
            -h|--help)
                USAGE=1;;
            *) :;;
        esac
    done
    reset_colors
    if [ "x${USAGE}" != "x" ]; then
        usage
    fi
}
has_command() {
    ret=1
    if which which >/dev/null 2>/dev/null;then
      if which "${@}" >/dev/null 2>/dev/null;then
        ret=0
      fi
    else
      if command -v "${@}" >/dev/null 2>/dev/null;then
        ret=0
      else
        if hash -r "${@}" >/dev/null 2>/dev/null;then
            ret=0
        fi
      fi
    fi
    return ${ret}
}
pipe_return() {
    local filter=$1;shift;local command=$@;
    (((($command; echo $? >&3) | $filter >&4) 3>&1) | (read xs; exit $xs)) 4>&1;
}
output_in_error() { ( do_trap output_in_error_post EXIT TERM QUIT INT;\
                      output_in_error_ "${@}" ; ); }
output_in_error_() {
    if [ "x${OUTPUT_IN_ERROR_DEBUG-}" != "x" ];then set -x;fi
    if ( is_ci );then
        DEFAULT_CI_BUILD=y
    fi
    CI_BUILD="${CI_BUILD-${DEFAULT_CI_BUILD-}}"
    if [ "x$CI_BUILD" != "x" ];then
        DEFAULT_NO_OUTPUT=y
        DEFAULT_DO_OUTPUT_TIMER=y
    fi
    VERBOSE="${VERBOSE-}"
    TIMER_FREQUENCE="${TIMER_FREQUENCE:-120}"
    NO_OUTPUT="${NO_OUTPUT-${DEFAULT_NO_OUTPUT-1}}"
    DO_OUTPUT_TIMER="${DO_OUTPUT_TIMER-$DEFAULT_DO_OUTPUT_TIMER}"
    LOG=${LOG-}
    if [ "x$NO_OUTPUT" != "x" ];then
        if [  "x${LOG}" = "x" ];then
            LOG=$(mktemp)
            DEFAULT_CLEANUP_LOG=y
        else
            DEFAULT_CLEANUP_LOG=
        fi
    else
        DEFAULT_CLEANUP_LOG=
    fi
    CLEANUP_LOG=${CLEANUP_LOG:-${DEFAULT_CLEANUP_LOG}}
    if [ "x$VERBOSE" != "x" ];then
        log "Running$([ "x$LOG" != "x" ] && echo "($LOG)"; ): $@";
    fi
    TMPTIMER=
    if [ "x${DO_OUTPUT_TIMER}" != "x" ]; then
        TMPTIMER=$(mktemp)
        ( i=0;\
          while test -f $TMPTIMER;do\
           i=$((++i));\
           if [ `expr $i % $TIMER_FREQUENCE` -eq 0 ];then \
               log "BuildInProgress$( if [ "x$LOG" != "x" ];then echo "($LOG)";fi ): ${@}";\
             i=0;\
           fi;\
           sleep 1;\
          done;\
          if [ "x$VERBOSE" != "x" ];then log "done: ${@}";fi; ) &
    fi
    # unset NO_OUTPUT= LOG= to prevent output_in_error children to be silent
    # at first
    reset_env="NO_OUTPUT LOG"
    if [ "x$NO_OUTPUT" != "x" ];then
        ( unset $reset_env;"${@}" ) >>"$LOG" 2>&1;ret=$?
    else
        if [ "x$LOG" != "x" ] && has_command tee;then
            ( unset $reset_env; pipe_return "tee -a $tlog" "${@}"; )
            ret=$?
        else
            ( unset $reset_env; "${@}"; )
            ret=$?
        fi
    fi
    if [ -e "$TMPTIMER" ]; then rm -f "${TMPTIMER}";fi
    if [ "x${OUTPUT_IN_ERROR_NO_WAIT-}" = "x" ];then wait;fi
    if [ -e "$LOG" ] &&  [ "x${ret}" != "x0" ] && [ "x$NO_OUTPUT" != "x" ];then
        cat "$LOG" >&2
    fi
    if [ "x${OUTPUT_IN_ERROR_DEBUG-}" != "x" ];then set +x;fi
    return ${ret}
}
output_in_error_post() {
    if [ -e "$TMPTIMER" ]; then rm -f "${TMPTIMER}";fi
    if [ -e "$LOG" ] && [ "x$CLEANUP_LOG" != "x" ];then rm -f "$LOG";fi
}
test_silent_log() { ( [ "x${NO_SILENT-}" = "x" ] && ( [ "x${SILENT_LOG-}" != "x" ] || [ x"${SILENT_DEBUG}" != "x" ] ) ); }
test_silent() { ( [ "x${NO_SILENT-}" = "x" ] && ( [ "x${SILENT-}" != "x" ] || test_silent_log ) ); }
silent_run_() {
    (LOG=${SILENT_LOG:-${LOG}};
     NO_OUTPUT=${NO_OUTPUT-};\
     if test_silent;then NO_OUTPUT=y;fi;output_in_error "$@";)
}
silent_run() { ( silent_run_ "${@}" ; ); }
run_silent() {
    (
    DEFAULT_RUN_SILENT=1;
    if [ "x${NO_SILENT-}" != "x" ];then DEFAULT_RUN_SILENT=;fi;
    SILENT=${SILENT-DEFAULT_RUN_SILENT} silent_run "${@}";
    )
}
vvv() { debug "${@}";silent_run "${@}"; }
vv() { log "${@}";silent_run "${@}"; }
silent_vv() { SILENT=${SILENT-1} vv "${@}"; }
quiet_vv() { if [ "x${QUIET-}" = "x" ];then log "${@}";fi;run_silent "${@}";}
#
get_git_changeset() { ( cd "${1:-$(pwd)}" && git log HEAD|head -n1|awk '{print $2}'); }
## end from glue
LOGGER_NAME="dockerimages-builder"
rc=0
THISSCRIPT=$0
W="$(dirname $(readlinkf $THISSCRIPT))"
cd "$W"
SDEBUG=${SDEBUG-}
if [[ -n $SDEBUG ]];then set -x;fi
DO_RELEASE=${DO_RELEASE-}
DEFAULT_REGISTRY=${DEFAULT_REGISTRY:-registry.hub.docker.com}
DOCKER_REPO=${DOCKER_REPO:-corpusops}
TOPDIR=$(pwd)
DEBUG=${DEBUG-}
FORCE_REBUILD=${FORCE_REBUILD-}
DRYRUN=${DRYRUN-}
NOREFRESH=${NOREFRESH-}
NBPARALLEL=${NBPARALLEL-2}
SKIP_TAGS_REBUILD=${SKIP_TAGS_REBUILD-}
SKIP_TAGS_REFRESH=${SKIP_TAGS_REFRESH-${SKIP_TAGS_REBUILD}}
SKIP_IMAGES_SCAN=${SKIP_IMAGES_SCAN-}
# SKIP_MINOR_NGINX="((nginx):.*[0-9]+\.[0-9]+\.[0-9]+(-32bit.*)?)"
MINOR_IMAGES="(golang|mariadb|memcached|mongo|mysql|nginx|node|php|postgres|python|rabbitmq|redis|redmine|ruby|solr)"
SKIP_MINOR_OS="$MINOR_IMAGES:.*alpine[0-9].*"
SKIP_MINOR="$MINOR_IMAGES:.*[0-9]+\.([0-9]+\.)[0-9]+(-32bit.*)?"
SKIP_PRE="((redis|node|ruby|php|golang|python|mariadb|mysql|postgres|solr|elasticsearch|mongo|rabbitmq):.*(alpha|beta|rc)[0-9]*(-32bit.*)?)"
SKIP_OS="(((archlinux|suse|centos|fedora|redhat|alpine|debian|ubuntu|oldstable|oldoldstable):.*[0-9]{8}.*)"
SKIP_OS="$SKIP_OS|((node):[0-9]+[0-9]+\.[0-9]+.*)"
SKIP_OS="$SKIP_OS|((debian|redis):[0-9]+\.[0-9]+.*)"
SKIP_OS="$SKIP_OS|(centos:.\..\.....|centos.\..\.....)"
SKIP_OS="$SKIP_OS|(alpine:.\.[0-9]+\.[0-9]+)"
SKIP_OS="$SKIP_OS|(debian:(6.*|squeeze))"
SKIP_OS="$SKIP_OS|(ubuntu:(([0-9][0-9]\.[0-9][0-9]\..*)|(14.10|12|10|11|13|15)))"
SKIP_OS="$SKIP_OS|(lucid|maverick|natty|precise|quantal|raring|saucy)"
SKIP_OS="$SKIP_OS|(centos:(centos)?5)"
SKIP_OS="$SKIP_OS|(fedora.*(modular|21))"
SKIP_OS="$SKIP_OS|(traefik:((camembert|cancoillotte|cantal|chevrotin|faisselle|livarot|maroilles|montdor|morbier|picodon|raclette|reblochon|roquefort|tetedemoine)(-alpine)?|rc.*|(v?([0-9]+\.[0-9]+\.).*$)))"
SKIP_OS="$SKIP_OS|(minio.*(armhf|aarch))"
SKIP_PHP="(php:(5.4|5.3|.*(RC|-rc-).*))"
SKIP_OS="$SKIP_OS)"
SKIP_WINDOWS="(.*(nanoserver|windows))"
SKIP_MISC="(-?(on.?build)|pgrouting.*old)|seafile-mc:(7.0.1|7.0.2|7.0.3|7.0.4|7.0.5|7.1.3)|(dejavu:(v.*|1\..\.?.?|2\..\..)|3\.[1-3]\..|3.0.0|.*alpha.*$)"
SKIP_NODE="((node):.*alpine3\..?.?)"
SKIP_TF="(tensorflow.serving:[0-9].*)"
SKIP_MINIO="(k8s-operator|((minio|mc):(RELEASE.)?[0-9]{4}-.{7}))"
SKIP_MAILU="(mailu.*(feat|patch|merg|refactor|revert|upgrade|fix-|pr-template))"
SKIP_DOCKER="docker(\/|:)([0-9]+\.[0-9]+\.|17|18.0[1-6]|1$|1(\.|-)).*"
SKIPPED_TAGS="$SKIP_TF|$SKIP_MINOR_OS|$SKIP_NODE|$SKIP_DOCKER|$SKIP_MINIO|$SKIP_MAILU|$SKIP_MINOR_ES2|$SKIP_MINOR|$SKIP_PRE|$SKIP_OS|$SKIP_PHP|$SKIP_WINDOWS|$SKIP_MISC"
CURRENT_TS=$(date +%s)
IMAGES_SKIP_NS="((mailhog|postgis|pgrouting(-bare)?|^library|dejavu|(minio/(minio|mc))))"

SKIP_POSTGRES="post.*:.*1[3-9].-[0-3]|postgres:(.*beta.*|.*alpine3.*|.*alpine.*|9\.[0-9]+\.[0-9]+.*|9\.0|8.*|1[09]\.[0-9].*)$"
SKIPPED_TAGS="$SKIP_MISC|$SKIP_PRE|$SKIP_POSTGRES|:(9|10|11)\.|:.*alpine.*"
default_images="
corpusops/postgis-bare
"
ONLY_ONE_MINOR="postgres|elasticsearch|nginx"
PROTECTED_TAGS="corpusops/rsyslog"
find_top_node_() {
    img=library/node
    if [ ! -e $img ];then return;fi
    for i in $(
        find $img -maxdepth 1 -mindepth 1 -type d \
        |grep -v chakra|grep -E -- "[^0-9.][0-9]+$"|grep -E "1."|sort -V)
    do
        for j in $(\
            find $i* -maxdepth 1 -mindepth 0 -type d \
            |grep -E "[0-9]+\.[0-9]+($|-alpine)$"\
            |sed -re 's!.*/!!'|sort -V|tail -n12);do
            ls -d $img/$j
        done
    done
}
find_top_node() { (set +e && find_top_node_ && set -e;); }
NODE_TOP="$(echo $(find_top_node))"
MAILU_VERSiON=1.7

BATCHED_IMAGES="\
corpusops/postgis-bare/15-3\
 corpusops/postgis-bare/14-3::30
corpusops/postgis-bare/13-3\
 corpusops/postgis-bare/12-3::30
corpusops/postgis-bare/11-3\
 corpusops/postgis-bare/11-2.5\
 corpusops/postgis-bare/10-2.4\
 corpusops/postgis-bare/10-2.5\
 corpusops/postgis-bare/10-3::30
corpusops/postgis-bare/9.0-2.1\
 corpusops/postgis-bare/9.1-2.1\
 corpusops/postgis-bare/9.1-2.2\
 corpusops/postgis-bare/9.2-2.2\
 corpusops/postgis-bare/9.2-2.3\
 corpusops/postgis-bare/9.3-2.3\
 corpusops/postgis-bare/9.3-2.4\
 corpusops/postgis-bare/9.4-2.3\
 corpusops/postgis-bare/9.4-2.5\
 corpusops/postgis-bare/9.5-2.4\
 corpusops/postgis-bare/9.5-2.5\
 corpusops/postgis-bare/9.6-2.4\
 corpusops/postgis-bare/9.6-2.5\
 corpusops/postgis-bare/9.4-2.4::32
"
SKIP_REFRESH_ANCESTORS=${SKIP_REFRESH_ANCESTORS-}
POSTGIS_MINOR_TAGS="
9.0-2.1
9.1-2.2
9.2-2.2 9.2-2.3
9.2-2.3
9.3-2.3 9.3-2.4
9.4-2.3 9.4-2.4 9.5-2.4 9.6-2.4
9.4-2.5 9.5-2.5 9.6-2.5
10-2.4 10-2.5 10-3
11-2.5 11-3
12-3
13-3
14-3
15-3
"
PGROUTING_MINOR_TAGS="
15-3-3.4
14-3-3.4
13-3-3.4
13-3-3.1
12-3-3.1
12-3-3.0
11-3-3.1
11-3-3.0
11-2.5-2.6
10-2.5-2.6
9.6-2.5-2.6

9.5-2.4-2.4
9.5-2.4-2.5
9.5-2.4-2.6
9.6-2.4-2.4
9.6-2.4-2.5
9.6-2.4-2.6
9.4-2.5-2.6
9.5-2.5-2.4
9.5-2.5-2.5
9.5-2.5-2.6
9.6-2.5-2.4
9.6-2.5-2.5
10-2.4-2.4
10-2.4-2.5
10-2.4-2.6
10-2.5-2.4
10-2.5-2.5
12-2.5-2.6
12-2.5-2.6
12-2.5-2.6
"
POSTGRES_MAJOR="9 10 11 12 13 14 15"
packagesUrlJessie='http://apt-archive.postgresql.org/pub/repos/apt/dists/jessie-pgdg/main/binary-amd64/Packages'
packagesJessie="local/$(echo "$packagesUrlJessie" | sed -r 's/[^a-zA-Z.-]+/-/g')"
packagesUrlStretch='http://apt-archive.postgresql.org/pub/repos/apt/dists/stretch-pgdg/main/binary-amd64/Packages'
packagesStretch="local/$(echo "$packagesUrlStretch" | sed -r 's/[^a-zA-Z.-]+/-/g')"
packagesUrlBuster='http://apt.postgresql.org/pub/repos/apt/dists/buster-pgdg/main/binary-amd64/Packages'
packagesBuster="local/$(echo "$packagesUrlBuster" | sed -r 's/[^a-zA-Z.-]+/-/g')"
packagesUrlBullseye='http://apt.postgresql.org/pub/repos/apt/dists/bullseye-pgdg/main/binary-amd64/Packages'
packagesBullseye="local/$(echo "$packagesUrlBullseye" | sed -r 's/[^a-zA-Z.-]+/-/g')"

PGROUTING_REPO="${PGROUTING_REPO:-"https://salsa.debian.org/debian-gis-team/pgrouting.git"}"
PGROUTING_UPSTREAM_REPO="${PGROUTING_UPSTREAM_REPO:-"https://github.com/pgRouting/pgrouting.git"}"

declare -A duplicated_tags
declare -A registry_tokens
declare -A registry_services
declare -A postgis_alpine_vers
postgis_alpine_vers[2.3]="2.3.11"
postgis_alpine_vers[2.3.11]="98b4bde783d6d2cda01ac268317ef83210370253f41c9dc937adeea2aa443dc3"
postgis_alpine_vers[2.4]="2.4.9"
postgis_alpine_vers[2.4.9]="77ba24bf8fbbfa65881d7d24bd6379f2001fff781d6ff512590bfaf16e605288"
postgis_alpine_vers[2.5]="2.5.5"
postgis_alpine_vers[2.5.5]="24b15ee36f3af02015da0e92a18f9046ea0b4fd24896196c8e6c2aa8e4b56baa"

is_on_build() { echo "$@" | grep -E -iq "on.*build"; }
slashcount() { local _slashcount="$(echo "${@}"|sed -e 's![^/]!!g')";echo ${#_slashcount}; }

## registry code badly inspired from:
## https://hackernoon.com/inspecting-docker-images-without-pulling-them-4de53d34a604
DEFAULT_REGISTRY=${DEFAULT_REGISTRY:-registry.hub.docker.com}
get_registry() {
    local image=$@
    local registry=${2:-$DEFAULT_REGISTRY}
    local slashcount="$(echo ${image}|sed -e 's![^/]!!g')"
    local nbslash=$(slashcount $image)
    if ( echo "$image" |grep -iq gitlab.com );then
        registry=registry.gitlab.com
    elif [ $nbslash -gt 1 ];then
        registry=$(echo $image|sed -e "s/\/.*//g")
    else
        registry="${registry}"
    fi
    if ( echo $registry | grep -vq -- "://" );then
        registry="${REGISTRY_SCHEME:-https://}${registry}"
    fi
    echo "$registry"
}

setup_token() {
    local registry=${1:-$(get_registry default)}
    if [[ -n "$1" ]];then shift;fi
    local oargs=${@}
    local args=$oargs
    local tkey=${registry}${oargs}
    registry_token=${registry_tokens[$tkey]}
    registry_service=${registry_services[$tkey]}
    if [[ -z "$registry_token" ]];then
        local authinfos=$(curl -vvv $registry/v2/ 2>&1|grep -i Www-Authenticate:)
        if ! ( echo  $authinfos | grep -E -iq "Www-Authenticate:.*realm.*service" );then
            return 1
        fi
        # Www-Authenticate: Bearer realm="https://...",service="registry..."
        local authendpoint=$(echo "$authinfos"|sed -e 's!.*realm="\([^"]\+\)".*!\1!g')
        registry_service=$(echo "$authinfos"|sed -e 's!.*service="\([^"]\+\)".*!\1!g')
        if [[ -n $args ]];then args="$args&";fi
        args="${args}service=$registry_service"
        registry_token=$(curl --silent "$authendpoint?$args" | jq -r '.token')
    fi
    if [[ -n $registry_token ]];then
        registry_tokens[$tkey]="$registry_token"
        registry_services[$tkey]="$registry_service"
    fi
}

get_image_scope() {
    echo "scope=repository:$1:pull"
}

get_image_tag() {
    local image="$1"
    if ( echo $image | grep -E -q ":[^/]+$" );then
        image=$( echo $image | sed -e 's!\(.*\):[^/]\+$!\1!' )
    fi
    echo $image
}

get_image_version() {
    local image="$1"
    if ( echo $image | grep -E -q ":[^/]+$" )
        then local tag=${1//*:/}
        else local tag=latest
    fi
    echo $tag
}

## Retrieve the digest, now specifying in the header
## that we have a token (so we can pe...
get_digest() {
    local fimage="$1"
    local image="$(get_image_tag $1)"
    local tag="$(get_image_version $1)"
    local registry="$(get_registry $1)"
    local scope="$(get_image_scope $image $registry)"
    setup_token $registry $scope
    ret=$(curl \
        --silent \
        --header "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        --header "Authorization: Bearer $registry_token" \
        "$registry/v2/$image/manifests/$tag" \
        | jq -r '.config.digest' 2>/dev/null || :)
    echo $ret
}

get_remote_image_configuration() {
    local image_query_args="${image_query_args:-"-M -r"}"
    local image_query="${image_query:-.}"
    local fimage="$1"
    local image="$(get_image_tag $1)"
    local tag="$(get_image_version $1)"
    local registry="$(get_registry $1)"
    local scope="$(get_image_scope $image $registry)"
    setup_token $registry $scope
    local digest=$(get_digest $fimage)
    curl \
        --silent \
        --location \
        --header "Authorization: Bearer $registry_token" \
        "$registry/v2/$image/blobs/$digest" \
        | jq $image_query_args "${image_query}"
}

is_an_image_ancestor() {
    local ancestor=$1
    local itag=$2
    local ret=1
    alastlayer=$( \
        image_query='.rootfs.diff_ids[-1]' \
        get_remote_image_configuration $ancestor 2>/dev/null || : )
    if [[ -n $alastlayer ]];then
        (image_query='.rootfs.diff_ids' \
            get_remote_image_configuration $itag 2>/dev/null || : ) | grep -E -q $alastlayer
        ret=$?
    fi
    return $ret
}

get_image_changeset() {
    ret=$(image_query='.config.Labels["com.github.corpusops.docker-images-commit"]' \
          get_remote_image_configuration $@ 2>/dev/null || : )
    if [ "x$ret" = "xnull" ];then ret="";fi
    echo "$ret"
}

do_gen_image() { gen_image "$@"; }
gen_image() {
    local image=$1 tag=$2
    local ldir="$TOPDIR/$image/$tag"
    local system=apt
    local dockeriles=""
    if [ ! -e "$ldir" ];then mkdir -p "$ldir";fi
    cd "$ldir"
    if ( echo "$image $tag"|grep -E -iq "redhat|centos|oracle|fedora|red-hat" );then
        system=redhat
    elif ( echo "$image $tag"|grep -E -iq suse );then
        system=suse
    elif ( echo "$image $tag"|grep -E -iq "mailhog|alpine" );then
        system=alpine
    fi
    IMG=$image
    if [ -e ../tag ];then
        IMG=$(cat ../tag )
    fi
    export _cops_BASE=$image
    export _cops_VERSION=$tag
    export _cops_IMG=$DOCKER_REPO/$(basename $IMG)
    debug "IMG: $_cops_IMG | BASE: $_cops_image | VERSION: $_cops_VERSION"
    for folder in . .. ../../..;do
        local df="$folder/Dockerfile.override"
        if [ -e "$df" ];then dockerfiles="$dockerfiles $df" && break;fi
    done
    local parts="from args argspost helpers pre base post clean cleanpost extra labels labelspost"
    for order in $parts;do
        for folder in . .. ../../..;do
            local df="$folder/Dockerfile.$order"
            if [ -e "$df" ];then dockerfiles="$dockerfiles $df" && break;fi
        done
    done
    if [[ -z $dockerfiles ]];then
        log "no dockerfile for $_cops_IMG"
        rc=1
        return $rc
    else
        debug "Using dockerfiles: $dockerfiles from $_cops_IMG"
    fi
    cat $dockerfiles | envsubst '$_cops_BASE;$_cops_VERSION;' > Dockerfile
    cd - &>/dev/null
}
### end - docker remote api

is_skipped() {
    local ret=1 t="$@"
    if [[ -z $SKIPPED_TAGS ]];then return 1;fi
    if ( echo "$t" | grep -E -q "$SKIPPED_TAGS" );then
        ret=0
    fi
    # if ( echo "$t" | grep -E -q "/traefik" ) && ( echo "$t" | grep -E -vq "alpine" );then
    #     ret=0
    # fi
    return $ret
}

skip_local() {
    grep -E -v "(.\/)?local|\.git"
}

#  get_namespace_tag libary/foo/bar : get image tag with its final namespace
do_get_namespace_tag() {
    local i=
    for image in $@;do
        local version=$(basename $image)
        local repo=$DOCKER_REPO
        local tag=$(basename $(dirname $image))
        if ! ( echo $image|grep -E -q "$IMAGES_SKIP_NS" );then
            local tag="$(dirname $(dirname $image))-$tag"
        fi
        for i in $image $image/.. $image/../../..;do
            # corpusops / foobar
            if [ -e $i/repo ];then repo=$( cat $i/repo );break;fi
        done
        for i in $image $image/.. $image/../../..;do
            # ubuntu-bare / postgis
            if [ -e $i/tag ];then tag=$( cat $i/tag );break;fi
        done
        for i in $image $image/.. $image/../../..;do
            # ubuntu-bare / postgis
            if [ -e $i/version ];then version=$( cat $i/version );break;fi
        done
        echo "$repo/$tag:$version" \
            | sed -re "s/(-?(server)?-(web-vault|elasticsearch|opensearch|postgresql|mysql|mongo|mongodb|maria|mariadb)):/-server:\3-/g"
    done
}


filter_tags() {
    for j in $@ ;do for i in $j;do
        if is_skipped "$n:$i";then debug "Skipped: $n:$i";else printf "$i\n";fi
    done;done | awk '!seen[$0]++' | sort -V
}

do_get_image_tags() { get_image_tags "$@"; }
get_image_tags() {
    local n=$1
    local results="" result=""
    local i=0
    local has_more=0
    local t="$TOPDIR/$n/imagetags"
    local u="https://registry.hub.docker.com/v2/repositories/${n}/tags/"
    local last_modified=$(stat -c "%Y" "$t.raw" 2>/dev/null )
    if [ -e "$t.raw" ] && [ $(($CURRENT_TS-$last_modified)) -lt $((24*60*60)) ];then
        has_more=1
    else
        has_more=0
    fi
    if [[ -z ${SKIP_TAGS_REFRESH} ]] && [ $has_more -eq 0 ];then
        while [ $has_more -eq 0 ];do
            i=$((i+1))
            result=$( curl "${u}?page=${i}" 2>/dev/null \
                | jq -r '."results"[]["name"]' 2>/dev/null )
            has_more=$?
            if [[ -n "${result}" ]];then results="${results} ${result}";else has_more=256;fi
        done
        if [ ! -e "$TOPDIR/$n" ];then mkdir -p "$TOPDIR/$n";fi
        printf "$results\n" | xargs -n 1 | sed -e "s/ //g" | sort -V > "$t.raw"
    fi
    # cleanup elastic minor images (keep latest)
    atags="$(filter_tags "$(cat $t.raw)")"
    changed=
    if ( echo $t | grep -E -q "$ONLY_ONE_MINOR" );then
        oomt=""
        for ix in $(seq 0 30);do
            if ! ( echo "$atags" | grep -E -q "^$ix\." );then continue;fi
            for j in $(seq 0 99);do
                if ! ( echo "$atags" | grep -E -q "^$ix\.${j}\." );then continue;fi
                for flavor in "" \
                    alpine alpine3.13 alpine3.14 alpine3.15 alpine3.16 alpine3.5 \
                    trusty xenial bionic focal jammy \
                    bullseye stretch buster jessie \
                    ;do
                    selected=""
                    if [[ -z "$flavor" ]];then
                        selected="$( (( echo "$atags" | grep -E "$ix\.$j\.[0-9]+$" )    || true )|sort -V )"
                    else
                        if ! ( echo "$atags" | grep -E -q "$ix\.$j\..*$flavor$" );then continue;fi
                        for k in $(seq 0 99);do
                            v=$( (( echo "$atags" | grep -E "$ix\.$j\.${k}.*$flavor$" ) || true )|sort -V )
                            if [[ -n $v ]];then
                                if [[ -n $selected ]];then selected="$selected $v";else selected="$v";fi
                            fi
                        done
                    fi
                    if [[ -n "$selected" ]];then
                        for l in $(echo "$selected"|sed -e "$ d");do
                            if [[ -z $oomt ]];then
                                oomt="$l$"
                            else
                                oomt="$oomt|$l"
                            fi
                        done
                    fi
                done
            done
            if [[ -n $oomt ]];then
                SKIPPED_TAGS="$SKIPPED_TAGS|(($ONLY_ONE_MINOR):($oomt)$)"
            fi
        done
    fi
    if [[ -z ${SKIP_TAGS_REBUILD} ]];then
        rm -f "$t"
        filter_tags "$atags" > $t
    fi
    set -e
    if [ -e "$t" ];then cat "$t";fi
}

make_tags() {
    local image=$1
    log "Operating on $image"
    local tags=$(get_image_tags $image )
    debug "image: $image tags: $( echo $tags )"
    for t in $tags;do if ! ( gen_image "$image" "$t"; );then rc=1;fi;done
}


#  clean_tags $i: clean image tags
do_clean_tags() {
    local image=$1
    log "Cleaning on $image"
    local tags=$(get_image_tags $image )
    debug "image: $image tags: $( echo $tags )"
    if [[ -z "$1" ]];then echo "no image";exit 1;fi
    while read image;do
        local tag=$(basename $image)
        if ! ( echo "$tags" | grep -E -q "^$tag$" );then
            rm -rfv "$image"
        fi
    done < <(find "$W/$image" -mindepth 1 -maxdepth 1 -type d 2>/dev/null|skip_local)
}

do_refresh_postgis() {
    curl -sSL "${packagesUrlJessie}.bz2"  | bunzip2 > "$packagesJessie"
    curl -sSL "${packagesUrlStretch}.bz2" | bunzip2 > "$packagesStretch"
    curl -sSL "${packagesUrlStretch}.bz2" | bunzip2 > "$packagesBuster"
    curl -sSL "${packagesUrlBullseye}.bz2" | bunzip2 > "$packagesBullseye"
    curl -sSL "${packagesUrlStretch}.bz2" | bunzip2 > "$packagesStretch"
    for version in $POSTGIS_MINOR_TAGS;do
        if (echo $version|grep -E -q "^(9.0|9.1|9.2)");then
            packages="$packagesJessie"
            debian_release=jessie
        elif (echo $version|grep -E -q "^(9|10|11)");then
            packages="$packagesStretch"
            debian_release=stretch
        elif (echo $version|grep -E -q "^(12)");then
            packages="$packagesBullseye"
            debian_release=bullseye
        elif (echo $version|grep -E -q "^(13|14|15|16)");then
            packages="$packagesBullseye"
            debian_release=bullseye
        else
            packages="$packagesBullseye"
            debian_release=bullseye
        fi
        IFS=- read pg_major postgis_major <<< "$version"
        img="corpusops/postgis-bare/$version"
        imgalpine="corpusops/postgis-bare/$version-alpine"
        fullVersion="$(grep -m1 -A10 "^Package: postgresql-$pg_major-postgis-$postgis_major\$" "$packages" | grep -m1 '^Version: ' | cut -d' ' -f2)"
        [ -z "$fullVersion" ] && { echo >&2 "Unable to find package for PostGIS $postgis_major on Postgres $pg_major"; exit 1; }
        for j in $img $imgalpine;do if [ ! -e "$j" ];then mkdir -p "$j";fi;done
        srcVersion="${fullVersion%%+*}"
        cachedsrcVersion="local/cached_postgis_sha_${srcVersion}"
        if [ -e "$cachedsrcVersion" ];then
            srcSha256="$(cat $cachedsrcVersion)"
        else
            srcSha256="$(curl -sSL "https://github.com/postgis/postgis/archive/$srcVersion.tar.gz" | sha256sum | awk '{ print $1 }')"
            echo "$srcSha256" > "$cachedsrcVersion"
        fi
        cp -vf Dockerfile.postgis.template        "$img/Dockerfile"
        cp -vf patch* "$img/"
        cp -vf docker-postgis/Dockerfile.alpine.template "$imgalpine/Dockerfile"
        dockerfile="$(: \
            && grep -E    "FROM" "$img/Dockerfile" \
            && cat Dockerfile.pre \
            && grep -E -v "FROM" "$img/Dockerfile" \
            && cat Dockerfile.post)"
        echo "$dockerfile" > "$img/Dockerfile"
        adockerfile="$(: \
            && grep -E    "FROM" "$imgalpine/Dockerfile" \
            && cat Dockerfile.alpine.pre \
            && grep -E -v "FROM" "$imgalpine/Dockerfile" \
            && cat Dockerfile.alpine.post)"
        adockerfile=$(python << EOF
# -*- coding: utf-8 -*-
from __future__ import print_function
import re, sys
data = '''${adockerfile//\\/\\\\}'''
data = data.replace('./autogen.sh', '''\
usermod -s /bin/sh postgres \
&& : end
ADD patch-configure.sh /
RUN set -ex && cd /usr/src/postgis && /patch-configure.sh configure* && ./autogen.sh \
&& export CFLAGS="\$CFLAGS -DACCEPT_USE_OF_DEPRECATED_PROJ_API_H=1" \
&& export CPPFLAGS="\$CFLAGS" && CPP_FLAGS="\$CFLAGS"''')
data = data.replace('proj4', 'proj')
d = ' sqlite-libs pkgconfig shadow bash'
data = data.replace('json-c-dev ', 'json-c-dev curl-dev expat-dev'+d)
data = data.replace('json-c  ', 'json-c curl libcurl expat'+d)
data = data.replace('su postgres -c ', 'su postgres -lc ')
print(data)
EOF
)
    echo "$adockerfile" > "$imgalpine/Dockerfile"
        if ( echo $imgalpine | grep -E -q "9.3.*alpine" ) && ( grep -vq jsonb.patch "$imgalpine/Dockerfile" );then
            sed -i -r \
                -e '/cd \/usr\/src\/postgis/ a\     && set -o pipefail && bzip2 -dck ../jsonb.patch.bz2|patch -Np1 \\' \
                -e '/MAINTAINER/ a ADD jsonb.patch.bz2 /usr/src' \
                "$imgalpine/Dockerfile"
        fi
        if ( echo $imgalpine | grep -E -q "/(9\.[2,3,4,5]-2.[2345]|2\.3)-alpine" );then
            sed -i -re 's/llvm10/llvm9/g' "$imgalpine/Dockerfile"
        fi
    cpostgis_alpine_version=${srcVersion}
    cpostgis_alpine_sha=${srcSha256}
    if [[ -v "postgis_alpine_vers[$postgis_major]" ]];then
        cpostgis_alpine_version=${postgis_alpine_vers[$postgis_major]}
        cpostgis_alpine_sha=${postgis_alpine_vers[$cpostgis_alpine_version]}
    fi
    sed -i 's/%%PG_MAJOR%%/'$pg_major'/g; s/%%POSTGIS_MAJOR%%/'$postgis_major'/g; s/%%POSTGIS_VERSION%%/'$fullVersion'/g' "$img/Dockerfile"
    sed -i 's/%%PG_MAJOR%%/'"$pg_major"'/g; s/%%POSTGIS_VERSION%%/'"$cpostgis_alpine_version"'/g; s/%%POSTGIS_SHA256%%/'"$cpostgis_alpine_sha"'/g' "$imgalpine/Dockerfile"
    done
    rm -rf corpusops/postgis-bare/*alpine
    rm -rf corpusops/postgis-bare/*12*2.5
}

#  refresh_images $args: refresh images files
#     refresh_images:  (no arg) refresh all images
#     refresh_images library/ubuntu: only refresh ubuntu images
do_refresh_images() {
    local imagess="${@:-$default_images}"
    if [[ -z ${SKIP_REFRESH_COPS-} ]];then
    if ! ( grep -q corpusops/docker-images .git/config );then
    if [ ! -e local/docker-images ];then
        git clone https://github.com/corpusops/docker-images local/docker-images
    fi
    ( cd local/docker-images && git fetch --all && git reset --hard origin/master \
      && cp -rf helpers       rootfs packages ../..; )
    fi
    fi
    POSTGIS_URL="https://github.com/appropriate/docker-postgis.git"
    if [ ! -e docker-postgis ];then git clone $POSTGIS_URL docker-postgis;fi
    ( cd docker-postgis && git fetch --all && git reset --hard origin/master; )
    cp -vf docker-postgis/*postgis*.sh .
    chmod +x *sh
    chmod -x initdb-*.sh
    rsync -azv --delete local/docker-images/helpers/ helpers/
    # code adapted from: docker-postgis/update.sh
    do_refresh_postgis
}

char_occurence() {
    local char=$1
    shift
    echo "$@" | awk -F"$char" '{print NF-1}'
}


get_image_from() {
    local lancestor=$(grep -E ^FROM "$1" |head -n1|awk '{print $2}')
    echo $lancestor
}

is_same_commit_label() {
    local git_commit="${1}"
    local itag="${2}"
    local ret=1
    local remote_git_commit=$(get_image_changeset $itag)
    if [ "x${git_commit}" = "x${remote_git_commit}" ];then
        ret=0
    fi
    return $ret
}

get_docker_squash_args() {
    DOCKER_DO_SQUASH=${DOCKER_DO_SQUASH-init}
    if ! ( echo "${NO_SQUASH-}"|grep -E -q "^(no)?$" );then
        DOCKER_DO_SQUASH=""
        log "no squash"
    elif [[ "$DOCKER_DO_SQUASH" = init ]];then
        DOCKER_DO_SQUASH="--squash"
        if ! (printf "FROM alpine\nRUN touch foo\n" | docker build --squash - >/dev/null 2>&1 );then
            DOCKER_DO_SQUASH=
            log "docker squash isnt not supported"
        fi
    fi
    echo $DOCKER_DO_SQUASH
}

set_global_tag() {
    val=${duplicated_tags[$1]}
    if [[ -n $val ]];then
        val="$val $2"
    else
        val="$2"
    fi
    duplicated_tags[$1]=$val
}

set_global_tags() {
    set_global_tag corpusops/postgis-bare:9.6-2.5        corpusops/postgis-bare:9.6
    set_global_tag corpusops/postgis-bare:9.5-2.5        corpusops/postgis-bare:9.5
    set_global_tag corpusops/postgis-bare:9.4-2.5        corpusops/postgis-bare:9.4
    set_global_tag corpusops/postgis-bare:9.3-2.4        corpusops/postgis-bare:9.3
    set_global_tag corpusops/postgis-bare:9.2-2.3        corpusops/postgis-bare:9.2
    set_global_tag corpusops/postgis-bare:9.1-2.2        corpusops/postgis-bare:9.1
    set_global_tag corpusops/postgis-bare:9.0-2.1        corpusops/postgis-bare:9.0
    set_global_tag corpusops/postgis-bare:9.6-2.5-alpine corpusops/postgis-bare:9.6-alpine
    set_global_tag corpusops/postgis-bare:9.5-2.5-alpine corpusops/postgis-bare:9.5-alpine
    set_global_tag corpusops/postgis-bare:9.4-2.5-alpine corpusops/postgis-bare:9.4-alpine
    set_global_tag corpusops/postgis-bare:9.3-2.4-alpine corpusops/postgis-bare:9.3-alpine
    set_global_tag corpusops/postgis-bare:9.2-2.3-alpine corpusops/postgis-bare:9.2-alpine
    set_global_tag corpusops/postgis-bare:9.6-2.5        corpusops/postgis-bare:9
    set_global_tag corpusops/postgis-bare:9.6-2.5-alpine corpusops/postgis-bare:9-alpine
    set_global_tag corpusops/postgis-bare:10-2.5         corpusops/postgis-bare:10
    set_global_tag corpusops/postgis-bare:10-2.5-alpine  corpusops/postgis-bare:10-alpine
    set_global_tag corpusops/postgis-bare:11-2.5         corpusops/postgis-bare:11
    set_global_tag corpusops/postgis-bare:11-2.5-alpine  corpusops/postgis-bare:11-alpine
    set_global_tag corpusops/postgis-bare:13-3-alpine    corpusops/postgis-bare:13-alpine
    set_global_tag corpusops/postgis-bare:13-3           corpusops/postgis-bare:13
    set_global_tag corpusops/postgis-bare:13-alpine      corpusops/postgis-bare:alpine
    set_global_tag corpusops/postgis-bare:14-3-alpine    corpusops/postgis-bare:14-alpine
    set_global_tag corpusops/postgis-bare:14-3           corpusops/postgis-bare:14
    set_global_tag corpusops/postgis-bare:14-alpine      corpusops/postgis-bare:alpine
    set_global_tag corpusops/postgis-bare:15-3-alpine    corpusops/postgis-bare:15-alpine
    set_global_tag corpusops/postgis-bare:15-3           corpusops/postgis-bare:15
    set_global_tag corpusops/postgis-bare:15             corpusops/postgis-bare:latest
    set_global_tag corpusops/postgis-bare:15-alpine      corpusops/postgis-bare:alpine
}

record_build_image() {
    # library/ubuntu/latest / corpusops/postgis/latest
    local image=$1
    # latest / latest
    local git_commit="${git_commit:-$(get_git_changeset "$W")}"
    local df=${df:-Dockerfile}
    local itag="$(do_get_namespace_tag $image)"
    local lancestor=$(get_image_from "$image/$df")
    if [[ -z "$FORCE_REBUILD" ]] && \
        ( is_an_image_ancestor $lancestor $itag ) && \
        ( is_same_commit_label $git_commit $itag );then
        log "Image $itag is update to date, skipping build"
        return
    fi
    dargs="${DOCKER_BUILD_ARGS-} $(get_docker_squash_args)"
    local dbuild="cat $image/$df|docker build ${dargs-}  -t $itag . -f - --build-arg=DOCKER_IMAGES_COMMIT=$git_commit"
    local retries=${DOCKER_BUILD_RETRIES:-2}
    local cmd="dret=8 && for i in \$(seq $retries);do if ($dbuild);then dret=0;break;else dret=6;fi;done"
    local cmd="$cmd && if [ \"x\$dret\" != \"x0\" ];then"
    local cmd="$cmd      echo \"${RED}$image/$df build: Failing after $retries retries${NORMAL}\" >&2"
    local cmd="$cmd      && false;fi"
    local run="echo -e \"${RED}$dbuild${NORMAL}\" && $cmd"
    local release_tags="$itag"
    for alt_tag in ${duplicated_tags[$itag]};do
        release_tags="$release_tags $alt_tag"
        run="$run && docker tag $itag $alt_tag"
    done
    if [[ -n "$DO_RELEASE" ]];then
        for itag in $release_tags;do
        run="$run && ./local/corpusops.bootstrap/hacking/docker_release $itag"
        done
        if [[ -n "${GITHUB_REF-}" ]];then
            for itag in $release_tags;do
            run="$run && ( docker rmi $itag || /bin/true )"
            done
            run="$run && (./local/corpusops.bootstrap/bin/cops_docker_cleanup.sh || /bin/true)"
        fi
    fi
    book="$(printf "$run\n${book}" )"
}

load_all_batched_images() {
    if [[ -z $_images_ ]];then
        while read imgs;do if [[ -n "$imgs" ]];then
            load_batched_images "${imgs//*::/}" "${imgs//::*/}"
        fi;done <<< "$BATCHED_IMAGES"
        _images_list_=$(echo "$_images_list_"|grep -E -v "^\s*$"| awk '!seen[$0]++'|sort -V)
    fi
}

#  [FORCE_REBUILD="" DOCKER_RELEASER="" DOCKER_PASSWORD="" DO_RELEASE=""] build $args: refresh images files
#     build:  (no arg) refresh all images
#     build library/ubuntu: only refresh ubuntu images
#     build library/ubuntu/latest: only refresh ubuntu:latest image
#     build zleftover:BATCH_QUARTED/BATCH_SIZE find images that wont be explictly built and build them per batch
#     If DO_RELEASE is set, image will be pushed using corpusops.bootstrap/hacking/docker_release
#     If FORCE_REBUILD is set, image will be rebuilt even if commit label of any existing remote image matches
# zleftover because of https://github.com/actions/runner/issues/483 , we want
# first jobs that produces specific images to run
do_build() {
    local images_args="${@:-$default_images}" images="" allcandidates=""
    # batch then all zleftover images that werent batched at first
    local i=
    if ( echo "$@" |grep -E -q zleftover: ) && [[ -z "${SKIP_IMAGES_SCAN}" ]];then
        load_all_batched_images
        for k in $(do_list_images);do
            for l in $(do_list_image $k);do
                if ! (echo "$_images_list_"|grep -E -q "^$l$");then
                    if [[ -n "$allcandidates" ]];then allcandidates="$allcandidates ";fi
                    allcandidates="${allcandidates}${l}"
                fi
            done
        done
    fi
    for imagepart in $images_args;do
        if ( echo $imagepart|grep -q zleftover);then
            local candidates=""
            local zleftover_re="zleftover:\([0-9]\+\)[/]\([0-9]\+\)"
            local part=$(  echo $imagepart|sed -e "s/$zleftover_re/\1/g" )
            local chunks=$(echo $imagepart|sed -e "s/$zleftover_re/\2/g" )
            local size=$(echo "$allcandidates"|wc -w)
            local chunksize="$(($size/$chunks))"
            local c=0 inf=$(($part-1)) sup=$part
            if [ $sup = $chunks ];then sup=$(($sup+1));fi
            debug "sup:$sup chunksize:$chunksize size:$size chunks:$chunks"
            for img in $allcandidates;do
                if [ $c -ge $(($inf*$chunksize)) ] && [ $c -lt $(($sup*$chunksize)) ];then
                    if [[ -n "$candidates" ]];then candidates="$candidates ";fi
                    candidates="${candidates}${img}"
                fi
                c=$(($c+1))
            done
            log "$imagepart candidates: $candidates"
            imagepart=$candidates
        fi
        if [[ -n "$imagepart" ]];then
            if [[ -n "$images" ]];then images="$images ";fi
            images="${images}$imagepart"
        fi
    done
    local to_build=""
    local i=
    for i in $images;do
        local number_of_slash=$( char_occurence / $i )
        if [ ! -e $i ];then
            sdie "$i: folder does not exist yet, use refresh_images ?"
        elif [ $number_of_slash = 1 ];then
            to_build="$to_build $(find $i -mindepth 1 -maxdepth 1 -type d|sed "s/^.\///g"|sort -V|skip_local)"
        elif [ $number_of_slash = 2 ];then
            to_build="$to_build $i"
        else
            sdie "$i: invalid number or slash: $number_of_slash"
        fi
    done
    local counter=0
    local book=""
    for i in $to_build;do
        record_build_image $i
        counter=$((counter+1))
    done
    book=$( echo "$book"|tac|awk '!seen[$0]++' )
    if [[ -n "$DO_RELEASE" ]];then
        do_refresh_corpusops
    fi
    if [[ -n $book ]];then
        if [ $NBPARALLEL -gt 1 ];then
            if ! ( has_command parallel );then
                die "install Gnu parallel (package: parrallel on most distrib)"
            fi
            # be sure env_parallel is loaded
            if ! ( echo "$book" | parallel --joblog build.log -j$NBPARALLEL --tty $( [[ -n $DRYRUN ]] && echo "--dry-run" ); );then
                rc=124
            fi
            if [ -e build.log ];then cat build.log;fi
        else
            while read cmd;do
                if [[ -n $cmd ]];then
                    if [[ -n $DRYRUN ]];then
                        log "Would have run $cmd"
                    else
                        bash -c "$cmd"
                    fi
                fi
            done <<< "$book"
        fi
    fi
    return $rc
}

#  is_image: validate dir is an image container
is_image() {
    test -e "$1/Dockerfile"
}

#  [SKIP_CORPUSOPS=] refresh_corpusops: install & upgrade corpusops
do_refresh_corpusops() {
    if [[ -z ${SKIP_CORPUSOPS-} ]];then
        if [[ -n $COPS_ROOT ]] && [ ! -e "$COPS_ROOT" ];then mkdir -p "$COPS_ROOT";fi
        vv .ansible/scripts/download_corpusops.sh
        vv .ansible/scripts/setup_corpusops.sh
    fi
}

#  list_image: list image subimages or subimage
do_list_image() {
    local i=
    ( if ( is_image "$@" );
    then echo "$@"
    else for i in $(find -mindepth 2 -type d|skip_local );do
             if [ -e "$i/Dockerfile" ];then echo "$i";fi;done
    fi ) \
    | grep -E "${@}" \
    | sed -re "s|(\./)?(([^/]+(/[^/]+)))(/.*)|\2\5|g"\
    | awk '!seen[$0]++' | sort -V
}

#  list_images: list images family
do_list_images() {
    local i=
    ( if ( is_image "$@" );
    then echo "$@"
    else for i in $(find -mindepth 2 -type d|skip_local );do
             if [ -e "$i/Dockerfile" ];then echo "$i";fi;done
    fi ) \
    | sed -re "s|(\./)?([^/]+/[^/]+)/.*|\2|g"\
    | awk '!seen[$0]++' | sort -V
}

is_in_images() {
    local ret=1
    local tomatch="$1"
    shift
    local i=""
    for i in $@;do if ( echo "$_images_list_"| grep -E -iq "^$i$" );then
        ret=0
        break
    fi;done
    return $ret
}

reset_images() {
    _images_=""
    _ghimages_=""
    _images_list_=""
}

## needs to be set:  $_images_/$_images_list_/$batch/$counter/$batchsize
load_batched_images() {
    local i=
    local batch="  - IMAGES=\""
    local ghbatch="        - \""
    local counter=0
    local default_batchsize=$1
    shift
    local batched_images="$(echo $@ |xargs -n1)"
    for i in $@;do
        local imgs=${i//::*}
        local batchsize=$default_batchsize
        if $(echo $i|grep -q ::);then batchsize=${i//*::};fi
        debug "_batch_images_($imgs :: $batchsize): $batch"
        debug "_ghbatch_images_($imgs :: $batchsize): $ghbatch"
        for img in $imgs;do
            debug "_batch_image_($img :: $batchsize): $batch"
            debug "_ghbatch_image_($img :: $batchsize): $ghbatch"
            local subimages=$(do_list_image $img)
            if [[ -z $subimages ]];then break;fi
            for j in $subimages;do
                if ! ( is_in_images $j ) && ( echo "$batched_images" | grep -E -q "^$j$");then
                    local space=" "
                    if [ `expr $counter % $batchsize` = 0 ];then
                        space=""
                        if [ $counter -gt 0 ];then
                            batch="$(printf -- "${batch}\"\n  - IMAGES=\""; )"
                            ghbatch="$(printf -- "${ghbatch}\"\n        - \""; )"
                        fi
                    fi
                    counter=$(( $counter+1 ))
                    _images_list_="$_images_list_
$j
                    "
                    batch="${batch}${space}${j}"
                    ghbatch="${ghbatch}${space}${j}"
                fi
            done
        done
    done
    if [ $counter -gt 0 ];then
        _images_="$(printf "${_images_}\n${batch}\"" )"
        _ghimages_="$(printf "${_ghimages_}\n${ghbatch}\"" )"
    fi
}

#  gen_gh; regenerate .github/workflows/cicd.yml file
do_gen_gh() {
    reset_images
    debug "_images_(pre): $_ghimages_"
    # batch first each explicily built images
    load_all_batched_images
    __IMAGES="$_ghimages_" \
        envsubst '$__IMAGES;' > "$W/.github/workflows/cicd.yml" \
        < "$W/.github/workflows/cicd.yml.in"
}


#  gen_travis; regenerate .travis.yml file
do_gen_travis() {
    reset_images
    debug "_images_(pre): $_images_"
    # batch first each explicily built images
    load_all_batched_images
    __IMAGES="$_images_" \
        envsubst '$__IMAGES;' > "$W/.travis.yml" \
        < "$W/.travis.yml.in"
}

#  gen: regenerate both images and travis.yml
do_gen() {
    if [[ -z "$NOREFRESH" ]];then do_refresh_images $@;fi
    do_gen_gh
}

do_make_tags() {
    make_tags $@
}

#  usage: show this help
do_usage() {
    echo "$0:"
    # Show autodoc help
    awk '{ if ($0 ~ /^#[^!#]/) { \
                gsub(/^#/, "", $0); print $0 } }' \
                "$THISSCRIPT"|grep -E -v "vim|^ colors"
    echo ""
}


do_main() {
    set_global_tags
    local args=${@:-usage}
    local actions="make_tags|refresh_corpusops|refresh_images|build|gen_travis|gen_gh|gen|list_images|clean_tags|get_namespace_tag|gen_image|get_image_tags"
    actions="@($actions)"
    action=${1-};
    if [[ -n "$@" ]];then shift;fi
    case $action in
        $actions) do_$action $@;;
        *) do_usage;;
    esac
    exit $rc
}
cd "$W"
do_main "$@"
# vim:set et sts=4 ts=4 tw=0:
